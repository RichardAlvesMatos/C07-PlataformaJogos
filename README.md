# C07-PlataformaJogos

Richard Alves Matos - GES 778 (4º Periodo) 
Gabriel Bolina Andrade 
|| 
Wagner de Paula Marques

Tema: Plataforma de Jogos

O objetivo do projeto é fazer um banco de dados para uma plataforma de jogos (como a Steam). O banco de dados armazena os clientes, suas carteiras digitais, sua biblioteca de jogos (Com DLCs), desenvolvedoras, categorias e os pedidos de compras, com varias chaves de jogos para serem ativadas

-----------------------------------------------------------------------------------------------------------
Tabelas:

  Cliente: O cliente possui uma senha armazenada como hash (SHA2) uma criptografia ||
  Carteira: possui relação de 1:1 com o Cliente ||
  Desenvolvedora: É ela quem publica os jogos na loja ||
  Categoria: Possui os gêneros de RPG, Ação, Puzzle, Roguelike e entre outros ||
  Jogo: Possui um catalogo de jogos e o JogoBase_DLC que é utilizado em caso o item seja uma dlc, assim apontando para o jogo base ||
  Jogo_Categoria: Cria uma relação de N:M entre Jogo e Categoria ||
  Pedido: É a compra de um cliente, com status PENDENTE, PAGO ou CANCELADO ||
  Item_Pedido: Cria uma relação de N:M entre Pedido e Jogo

------------------------------------------------------------------------------------------------------------
Relacionamentos:

  1:1 - Cliente e Carteira ||
  1:N - Cliente e Pedido; Pedido e Item_Pedido; Desenvolvedora e Jogo ||
  N:M - Jogo e Categoria; Pedido e Jogo ||
  Auto-relacionamento - Jogo com o Próprio Jogo (jogo pode ser uma dlc de jogo, se JogoBase_DLC apontar para outro jogo)

-------------------------------------------------------------------------------------------------------------
Restrições de integridade:

  PRIMARY KEY / AUTO INCREMENT - Todas as tabelas compostas em Jogo_Categoria e Item_Pedido possuem ||
  FOREIGN KEY - Possui ON DELETE CASCADE (carteira, categorias do jogo, itens do pedido) e um set null no jogo base da dlc ||
  UNIQUE - No Cliente.email e Carteira.Cliente_idCliente ||
  CHECK - saldo não pode ser menor que 0, preco nao pode ser menor que 0, classificação indicativa, status de pagamento, valorTotal e precoUnitario

-------------------------------------------------------------------------------------------------------------------------
Comandos DML:

INSERT - Popular o banco de dados para testar relacionamentos, regras e a integridade do banco de dados. ||
INSERT com LAST_INSERT_ID() - cria uma carteira ja vinculada ao cliente que foi recem inserido no banco de dados, retirando a necessidade de inserir seus dados manualmente ||
UPDATE - Altera os dados que ja existem sem apagar ou recriar os registros anteriores, por exemplo uma promoção apenas altera o Jogo.preco os pedidos antigos nao mudariam, já que Item_Pedido.precoUnitario guarda sempre o preço de quando a compra foi feita ||
