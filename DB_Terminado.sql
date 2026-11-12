DROP DATABASE IF EXISTS platafoma_jogos_db;
CREATE DATABASE plataforma_jogos;
USE plataforma_jogos;

CREATE TABLE Cliente(
	idCliente INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE KEY NOT NULL,
    senha VARCHAR(255) UNIQUE KEY NOT NULL,
    cpf CHAR(14) NOT NULL,
	dataCadastro DATE NOT NULL DEFAULT(CURRENT_DATE)
);
    
CREATE TABLE Carteira (
    idCarteira INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    saldo DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (saldo >= 0),
    Cliente_idCliente INT NOT NULL UNIQUE,
    CONSTRAINT fk_Carteira_Cliente FOREIGN KEY (Cliente_idCliente)
        REFERENCES Cliente (idCliente) ON DELETE CASCADE
);
    
CREATE TABLE Desenvolvedora(

	idDesenvolvedora INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(60) NOT NULL
);
    
CREATE TABLE Categoria(

	id_Categoria INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    nome VARCHAR(255) NOT NULL
);

CREATE TABLE Jogo(

	idJogo INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
	titulo VARCHAR(255) NOT NULL,
    descricao VARCHAR(255),
    preco FLOAT NOT NULL CHECK (preco >= 0),
    dataLancamento DATE NOT NULL,
    classificacaoIndicativa INT NOT NULL DEFAULT 0 CHECK(classificacaoIndicativa IN (0, 10, 12, 14, 16, 18)),
    desenvolvedora_id_Desenvolvedora INT NOT NULL,
    JogoBase_DLC INT NULL,
    CONSTRAINT fk_Jogo_Desenvolvedora FOREIGN KEY (desenvolvedora_idDesenvolvedora) REFERENCES Desenvolvedora (idDesenvolvedora),
    CONSTRAINT fk_Jogo_Base FOREIGN KEY (JogoBase_DLC) REFERENCES Jogo (idJogo) ON DELETE SET NULL
);

CREATE TABLE Jogo_Categoria(

	Jogo_idJogo INT PRIMARY KEY NOT NULL,
    Categoria_idCategoria INT PRIMARY KEY NOT NULL,
    CONSTRAINT fk_Jogo_Categoria_Jogo FOREIGN KEY (Jogo_idJogo) REFERENCES Jogo (idJogo) ON DELETE CASCADE,
    CONSTRAINT fk_Jogo_Categoria_Categoria FOREIGN KEY (Categoria_idCategoria) REFERENCES Categoria (idCategoria) ON DELETE CASCADE
);

CREATE TABLE Pedido(

	idPedido INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    dataPedido DATE NOT NULL DEFAULT(CURRENT_DATE),
    valorTotal Float NOT NULL DEFAULT 0,
    statusPedido VARCHAR(45) NOT NULL DEFAULT 'PENDENTE' CHECK(statusPedido IN ('PENDENTE', 'PAGO', 'CANCELADO')),
    Cliente_idCliente INT NOT NULL,
    CONSTRAINT fk_Pedido_Cliente FOREIGN KEY (Cliente_idCliente) REFERENCES Cliente (idCliente),
    CONSTRAINT ck_Pedido_Valor CHECK (valorTotal >= 0)
);

CREATE TABLE Item_Pedido(

	Pedido_idPedido INT PRIMARY KEY NOT NULL,
    Jogo_idJogo INT PRIMARY KEY NOT NULL,
    precoUnitario FLOAT NOT NULL CHECK(precoUnitario >= 0),
    chaveAtivacao VARCHAR(45) NULL,
    CONSTRAINT fk_Item_Pedido_Pedido FOREIGN KEY (Pedido_idPedido) REFERENCES Pedido (idPedido) ON DELETE CASCADE,
    CONSTRAINT fk_Item_Pedido_Jogo FOREIGN KEY (Jogo_idJogo) REFERENCES Jogo (idJogo)
);

DELIMITER $$
CREATE FUNCTION fn_total_gasto_cliente(p_idCliente INT)
RETURNS FLOAT
BEGIN
	RETURN (SELECT COALESCE(SUM(valorTotal), 0)
		FROM Pedido WHERE Clinte_idCliente = p_idCliente AND status = 'PAGO');
END$$

CREATE TRIGGER trg_item_pedido_ai
	AFTER INSERT ON Item_Pedido
    FOR EACH ROW
    BEGIN
		UPDATE Pedido
			SET valorTotal = (SELECT COALESCE(SUM(precoUnitario), 0)
            FROM Item_Pedido
WHERE Pedido_idPedido = NEW.Pedido_idPedido) WHERE idPEDIDO = NEW.Pedido_idPedido;

END $$

CREATE TRIGGER trg_item_pedido_ad
	AFTER DELETE ON Item_Pedido
    FOR EACH ROW
    BEGIN
		UPDATE Pedido
			SET valorTotal = (SELECT COALESCE(SUM(precoUnitario), 0)
            FROM Item_Pedido
            WHERE Pedido_idPedido = OLD.Pedido_idPedido)
				WHERE idPedido = OLD.Pedido_idPedido;
                
END$$

CREATE PROCEDURE sp_pagar_pedido(IN p_idPedido INT)
	BEGIN
		START TRANSACTION;
        
        SET @v_idCliente = NULL; /* @v_idCliente e todos outros valores do tipo guardam variaveis para eu conseguir usar depois no codigo, assim consigo melhorar ele */
        SET @v_status = NULL;
        SET @v_total = NULL;
        SET @v_saldo = NULL;
        
        SELECT Cliente_idCliente, statusPedido, valorTotal 
        INTO @v_idCliente, @v_status, @v_total 
        FROM Pedido WHERE idPedido = p_idPedido 
        FOR UPDATE;
        IF @v_status IS NULL THEN ROLLBACK;
			SELECT 'Pedido não encontrado.' AS mensagem;
		ELSEIF @v_statis <> 'PENDENTE' THEN 
			ROLLBACK;
			SELECT 'Seu pedigo NÃO ESTA PENDENTE.' AS mensagem;
		ELSEIF @v_total <= 0 THEN
			ROLLBACK;
            SELECT 'Pedido sem itens' AS mensagem;
        ELSE
			SELECT saldo INTo @v_saldo
				FROM Carteira
                WHERE Cliente_idCliente = @v_idCliente
                 FOR UPDATE;
			
            IF @v_saldo IS NULL OR @v_saldo < @v_total THEN
				ROLLBACK;
                SELECT 'Saldo insuficiente na carteira.' AS mensagem;
			
            ELSE
				UPDATE Carteira SET saldo = saldo - @v_total WHERE Cliente_idCliente = @v_idCliente;
				UPDATE Pedido SET status = 'PAGO' WHERE idPedido = p_idPedido;
                
                UPDATE Item_Pedido
					SET chaveAtivacao = UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 20))
					WHERE Pedido_idPedido = p_idPedido
                    AND chaveAtivacao IS NULL;
                    
                    COMMIT;
                    SELECT 'Pedido pago com sucesso.' AS mensagem;
				END IF;
			END IF;
		END$$
	DELIMITER ;
    
    CREATE VIEW vw_vendas_detalhadas AS 
		SELECT p.idPedido, p.dataPedido, p.status, c.idCliente, c.nome AS cliente, j.titutlo AS jogo, d.nome AS desenvolvedora, ip.precoUnitario, ip.chaveAtivacao
			FROM Pedido p JOIN CLIENTE c
            ON c.idCliente = p.Cliente_idCliente
            JOIN Item_Pedido ip
            ON ip.Pedido_idPedido = p.idPedido
            JOIN Jogo j 
            ON j.idJogo = ip.Jogo_idJogo
            JOIN Desenvolvedora d ON d.idDesenvovledora = j.Desenvolvedora_idDesenvolvedora;
	
    CREATE VIEW vw_catalogo_jogos AS /*GROUP_CONCAT junta todos os valores de uma string em uma unica linha */
    SELECt j.idJogo, j.titulo, d.nome AS desenvolvedora, j.preco, j.classificacaoIndicativa, jb.titulo AS jogoBase, 
    GROUP_CONCAT(cat.nome ORDER BY cat.nome SEPARATOR', ') AS categorias 
    FROM Jogo JOIN Desenvolvedora d
    ON d.idDesenvolvedora = j.Desenvovledora_idDesenvolvedora
    LEFT JOIN Jogo jb 
    ON jb.idJogo = j.JogoBase_DLC
	LEFT JOIN Jogo_Categoria jc
    ON jc.Jogo_idJogo = j.idJogo
    LEFT JOIN Categoria cat ON cat.idCategoria = jc.Categoria_idCategoria
GROUP BY j.idJogo, j.titulo, d.nome, j.preco, j.classificacaoIndicativa, jb.titulo;


INSERT INTO Cliente (nome, email, senha, cpf, dataCadastro) VALUES /* SHA2 é criptografia para usar na senha */
	('Ana Souza', 'ana.souza@email.com', SHA2('ana@2024', 256), '123.456.789-01', '2024-01-10'),
	('Bruno Lima', 'bruno.lima@email.com', SHA2('bruno@2024', 256), '234.567.890-12', '2024-02-15'),
	('Carla Mendes', 'carla.mendes@email.com', SHA2('carla@2024', 256), '345.678.901-23', '2024-03-20'),
	('Diego Alves', 'diego.alves@email.com', SHA2('diego@2024', 256), '456.789.012-34', '2024-05-05'),
	('Eduarda Rocha', 'eduarda.rocha@email.com', SHA2('eduarda@2024', 256), '567.890.123-45', '2024-06-18'),
	('Felipe Costa', 'felipe.costa@email.com', SHA2('felipe@2024', 256), '678.901.234-56', '2024-08-30');


INSERT INTO Carteira (saldo, Cliente_idCliente) VALUES
(150.00, 1),
(50.00, 2),
(300.00, 3),
(0.00, 4),
(80.00, 5),
(20.00, 6);
    
INSERT INTO Desenvolvedora (nome) VALUES
('CD Projekt RED'),
('Valve'),
('Mojang Studios'),
('Supergiant Games'),
('Team Cherry');

INSERT INTO Categoria (nome) VALUES
('RPG'),
('Ação'),
('Puzzle'),
('Aventura'),
('Sandbox'),
('Metroidvania'),
('Roguelike');

INSERT INTO Jogo (titulo, descricao, preco, dataLancamento, classificacaoIndicativa, Desenvolvedora_idDesenvolvedora, JogoBase_DLC) VALUES
('The Witcher 3: Wild Hunt', 'RPG de mundo aberto com o caçador de monstros Geralt.', 79.99, '2015-05-19', 18, 1, NULL),
('The Witcher 3: Blood and Wine', 'Expansão com a nova região de Toussaint.', 39.99, '2016-05-31', 18, 1, 1),
('Portal 2', 'Quebra-cabeças em primeira pessoa com portais.', 36.99, '2011-04-19', 10, 2, NULL),
('Half-Life: Alyx', 'Ação em realidade virtual no universo Half-Life.', 59.99, '2020-03-23', 16, 2, NULL),
('Minecraft', 'Construa e explore mundos infinitos de blocos.', 99.99, '2011-11-18',  0, 3, NULL),
('Hades', 'Roguelike de ação: escape do submundo grego.', 47.99, '2020-09-17', 12, 4, NULL),
('Hollow Knight', 'Aventura metroidvania em um reino de insetos.', 27.99, '2017-02-24', 10, 5, NULL);


INSERT INTO Jogo_Categoria (Jogo_idJogo, Categoria_idCategoria) VALUES
(1, 1), (1, 4),
(2, 1), (2, 4),
(3, 3), (3, 4),
(4, 2), (4, 4),
(5, 5), (5, 4),
(6, 7), (6, 2),
(7, 6), (7, 4);

('CD Projekt RED'),
('Valve'),
('Mojang Studios'),
('Supergiant Games'),
('Team Cherry');

INSERT INTO Categoria (nome) VALUES
('RPG'),
('Ação'),
('Puzzle'),
('Aventura'),
('Sandbox'),
('Metroidvania'),
('Roguelike');

INSERT INTO Jogo (titulo, descricao, preco, dataLancamento, classificacaoIndicativa, Desenvolvedora_idDesenvolvedora, JogoBase_DLC) VALUES
('The Witcher 3: Wild Hunt',     'RPG de mundo aberto com o caçador de monstros Geralt.', 79.99, '2015-05-19', 18, 1, NULL),
('The Witcher 3: Blood and Wine','Expansão com a nova região de Toussaint.',              39.99, '2016-05-31', 18, 1, 1),
('Portal 2',                     'Quebra-cabeças em primeira pessoa com portais.',        36.99, '2011-04-19', 10, 2, NULL),
('Half-Life: Alyx',              'Ação em realidade virtual no universo Half-Life.',      59.99, '2020-03-23', 16, 2, NULL),
('Minecraft',                    'Construa e explore mundos infinitos de blocos.',        99.99, '2011-11-18',  0, 3, NULL),
('Hades',                        'Roguelike de ação: escape do submundo grego.',          47.99, '2020-09-17', 12, 4, NULL),
('Hollow Knight',                'Aventura metroidvania em um reino de insetos.',         27.99, '2017-02-24', 10, 5, NULL);

INSERT INTO Jogo_Categoria (Jogo_idJogo, Categoria_idCategoria) VALUES
(1, 1), (1, 4),
(2, 1), (2, 4),
(3, 3), (3, 4),
(4, 2), (4, 4),
(5, 5), (5, 4),
(6, 7), (6, 2),
(7, 6), (7, 4);

INSERT INTO Pedido (dataPedido, status, Cliente_idCliente) VALUES
('2024-09-01', 'PAGO', 1),
('2024-09-03', 'PAGO', 2),
('2024-09-10', 'PAGO', 3),
('2024-09-15', 'PAGO', 1),
('2024-10-02', 'PENDENTE', 4),
('2024-10-05', 'PENDENTE', 5),
('2024-10-07', 'CANCELADO', 2);

INSERT INTO Item_Pedido (Pedido_idPedido, Jogo_idJogo, precoUnitario, chaveAtivacao) VALUES
(1, 1, 79.99, 'WITCH-3AAAA-11111-AAAA'),
(1, 6, 47.99, 'HADES-BBBBB-22222-BBBB'),
(2, 3, 36.99, 'PORTL-CCCCC-33333-CCCC'),
(3, 5, 99.99, 'MINEC-DDDDD-44444-DDDD'),
(3, 7, 27.99, 'HOLLO-EEEEE-55555-EEEE'),
(4, 2, 39.99, 'WITCH-FFFFF-66666-FFFF'),
(5, 4, 59.99, NULL),
(6, 3, 36.99, NULL),
(6, 7, 27.99, NULL),
(7, 4, 59.99, NULL);

INSERT INTO Cliente (nome, email, senha, cpf)
VALUES ('Gabriela Nunes', 'gabriela.nunes@email.com', SHA2('gabriela@2024', 256), '789.012.345-67');

INSERT INTO Carteira (saldo, Cliente_idCliente)
VALUES (0, LAST_INSERT_ID());

UPDATE Jogo SET preco = ROUND(preco * 0.90, 2) WHERE titulo = 'Minecraft';

UPDATE Carteira SET saldo = saldo + 70 WHERE Cliente_idCliente = 4;

DELETE FROM Pedido WHERE idPedido = 7 AND status = 'CANCELADO';

DROP USER IF EXISTS 'atendente_ana'@'localhost';

DROP USER IF EXISTS 'atendente_bruno'@'localhost';

DROP ROLE IF EXISTS 'role_atendimento';

CREATE ROLE 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Cliente TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Carteira TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Jogo TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Categoria TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Jogo_Categoria TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.Desenvolvedora TO 'role_atendimento';

GRANT SELECT, INSERT, UPDATE ON plataforma_jogos.Pedido TO 'role_atendimento';

GRANT SELECT, INSERT ON plataforma_jogos.Item_Pedido TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.vw_vendas_detalhadas TO 'role_atendimento';

GRANT SELECT ON plataforma_jogos.vw_catalogo_jogos TO 'role_atendimento';

GRANT EXECUTE ON PROCEDURE plataforma_jogos.sp_pagar_pedido TO 'role_atendimento';

GRANT EXECUTE ON FUNCTION plataforma_jogos.fn_total_gasto_cliente TO 'role_atendimento';

SET DEFAULT ROLE 'role_atendimento' TO 'atendente_ana'@'localhost', 'atendente_bruno'@'localhost';

SHOW GRANTS FOR 'atendente_ana'@'localhost' USING 'role_atendimento';

SHOW GRANTS FOR 'atendente_bruno'@'localhost' USING 'role_atendimento';

SELECT c.idCliente, c.nome, c.email, ca.saldo FROM Cliente c
	JOIN Carteira ca 
    ON ca.Cliente_idCliente = c.idCliente
ORDER BY ca.saldo DESC;

SELECT c.nome, COUNT(p.idPedido) AS qtd_pedidos, /* ROUND ARREDONDA, SUM SOMA, COALESCE RETORNA PRIMEIRO VALOR NAO NULO */
	ROUND(COALESCE(SUM(p.valorTotal), 0), 2) AS total_pedidos
    FROM Cliente c
    LEFT JOIN Pedido p
    ON p.Cliente_idCliente = c.idCliente
    GROUP BY c.idCliente, c.nome
 ORDER BY total_pedidos DESC;

SELECT d.nome AS desenvolvedora,
	j.titulo AS jogo, jb.titulo AS jogo_base, j.preco
	FROM Desenvolvedora d JOIN Jogo j
    ON j.Desenvolvedora_idDesenvolvedora = d.idDesenvolvedora
    LEFT JOIN Jogo jb 
    ON jb.idJogo = j.JogoBase_DLC
 ORDER BY d.nome, j.titulo;

SELECT cat.nome AS categoria, COUNT(*) AS qtd_jogos,
	GROUP_CONCAT(j.titulo 
	ORDER BY j.titulo 
	SEPARATOR ', ') AS jogos
	FROM Categoria cat JOIN Jogo_Categoria jc
    ON jc.Categoria_idCategoria = cat.idCategoria
    JOIN Jogo j
    ON j.idJogo = jc.Jogo_idJogo
 GROUP BY cat.idCategoria, cat.nome
 ORDER BY qtd_jogos DESC, cat.nome;

SELECT * FROM vw_vendas_detalhadas ORDER BY idPedido, jogo;

SELECT j.titulo, COUNT(*) AS unidades_vendidas,
	ROUND(SUM(ip.precoUnitario), 2)  AS receita
	FROM Item_Pedido ip JOIN Pedido p
	ON p.idPedido = ip.Pedido_idPedido
	JOIN Jogo j   
	ON j.idJogo   = ip.Jogo_idJogo WHERE p.status = 'PAGO'
 GROUP BY j.idJogo, j.titulo HAVING COUNT(*) >= 1 ORDER BY receita DESC;

SELECT c.idCliente, c.nome, c.email
	FROM Cliente c LEFT JOIN Pedido p 
    ON p.Cliente_idCliente = c.idCliente WHERE p.idPedido IS NULL;

SELECT c.nome, fn_total_gasto_cliente(c.idCliente) AS total_gasto
	FROM Cliente c
    ORDER BY total_gasto DESC;

SELECT * FROM vw_catalogo_jogos ORDER BY titulo;

SELECT idPedido, valorTotal 
	FROM Pedido 
    WHERE idPedido = 5;
    
INSERT INTO Item_Pedido (Pedido_idPedido, Jogo_idJogo, precoUnitario) 
	VALUES 
	(5, 3, 36.99);

SELECT idPedido, valorTotal FROM Pedido WHERE idPedido = 5;

DELETE FROM Item_Pedido WHERE Pedido_idPedido = 5 AND Jogo_idJogo = 3;

SELECT idPedido, valorTotal FROM Pedido WHERE idPedido = 5;

CALL sp_pagar_pedido(5);
CALL sp_pagar_pedido(6);

SELECT idPedido, status, valorTotal FROM Pedido WHERE idPedido IN (5, 6);

SELECT Pedido_idPedido, Jogo_idJogo, chaveAtivacao FROM Item_Pedido WHERE Pedido_idPedido IN (5, 6);

SELECT Cliente_idCliente, saldo FROM Carteira WHERE Cliente_idCliente IN (4, 5);
SELECT Cliente_idCliente, saldo FROM Carteira WHERE Cliente_idCliente IN (4, 5);