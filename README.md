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

-----------------------------------------------------------------------------------------------------------------
Comandos DML:

INSERT - Popular o banco de dados para testar relacionamentos, regras e a integridade do banco de dados. ||
INSERT com LAST_INSERT_ID() - cria uma carteira ja vinculada ao cliente que foi recem inserido no banco de dados, retirando a necessidade de inserir seus dados manualmente ||
UPDATE - Altera os dados que ja existem sem apagar ou recriar os registros anteriores, por exemplo uma promoção apenas altera o Jogo.preco os pedidos antigos nao mudariam, já que Item_Pedido.precoUnitario guarda sempre o preço de quando a compra foi feita ||
DELETE - Apaga dados que não são mais necessários (possui ON DELETE CASCADE e AND statusPedido = 'CANCELADO' para evitar apagar por engano um pedido que esá como válido).

-----------------------------------------------------------------------------------------------------------------
Role e usuários:

  role_atendimento - É a função (ROLE) que junta todas as permissões do atendimento num lugar só: || SELECT em Cliente, Carteira, Jogo, Categoria, Jogo_Categoria e Desenvolvedora || SELECT, INSERT e UPDATE em Pedido || SELECT e INSERT em Item_Pedido (sem UPDATE, o atendimento não altera itens que ja foram registrados) || SELECT nas views vw_vendas_detalhadas e vw_catalogo_jogos || EXECUTE na procedure sp_pagar_pedido e na function fn_total_gasto_cliente || atendente_ana e atendente_bruno - São os dois usuários ligados a role_atendimento. O SET DEFAULT ROLE faz a role ser ativada sozinha quando o usuário entra (no MySQL a role não vale na sessão se não for ativada)

------------------------------------------------------------------------------------------------------------------
Consultas com JOIN:

1 - 1:1 - Cliente e Carteira - mostra o saldo de cada cliente, do maior para o menor || 2 - 1:N - Cliente e Pedido - quantidade de pedidos e valor total de cada cliente, o LEFT JOIN mantém os clientes que nunca compraram || 3 - 1:N e auto-relacionamento - Desenvolvedora, Jogo e Jogo - jogos de cada desenvolvedora e, quando for uma dlc, o título do jogo base || 4 - N:M - Categoria, Jogo_Categoria e Jogo - quantidade de jogos por categoria, com os títulos agrupados em uma linha usando GROUP_CONCAT || 5 - View vw_vendas_detalhadas - cada item vendido com cliente, jogo, desenvolvedora, preço e chave de ativação || 6 - N:M - Item_Pedido, Pedido e Jogo - unidades vendidas e receita de cada jogo, só de pedidos PAGO (usa GROUP BY e HAVING) || 7 - LEFT JOIN com IS NULL - clientes que nunca fizeram um pedido || 8 - Function - total gasto por cliente usando a fn_total_gasto_cliente || 9 - View vw_catalogo_jogos - catalogo completo da loja

-----------------------------------------------------------------------------------------------------------------
Function, Triggers, Procedure e Views:

  FUNCTION fn_total_gasto_cliente(p_idCliente) - Retorna a soma dos pedidos PAGO de um cliente (ou 0 se ele não tiver nenhum).

  TRIGGER trg_item_pedido_ai - Dispara depois de um INSERT em Item_Pedido e recalcula o valorTotal do Pedido, somando os precoUnitario dos itens || TRIGGER trg_item_pedido_ad - Dispara depois de um DELETE em Item_Pedido e recalcula o valorTotal da mesma forma || Por que foram criados? - O valorTotal é um dado que depende dos itens do pedido. Com os triggers ele fica sempre correto mesmo que os valores sejam alterados

  PROCEDURE sp_pagar_pedido(p_idPedido) - Faz o pagamento de um pedido dentro de uma transação, nesta ordem: || 1 - Busca o cliente, o status e o total do pedido com SELECT ... FOR UPDATE (trava o registro para o pedido não ser pago duas vezes ao mesmo tempo) || 2 - Verifica se o pedido existe, se está PENDENTE e se tem itens || 3 - Busca o saldo da carteira do cliente (também com FOR UPDATE) e verifica se ele cobre o total || 4 - Debita o valor da Carteira e muda o statusPedido para PAGO || 5 - Gera a chaveAtivacao dos itens que ainda não têm: UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 20)) || 6 - Confirma tudo com COMMIT || Se alguma verificação falhar ela faz ROLLBACK e mostra uma mensagem (pedido não encontrado, pedido não está pendente, pedido sem itens ou saldo insuficiente). Se der certo mostra "Pedido pago com sucesso." || Por que foi criada? - Pagar envolve várias operações que precisam acontecer juntas (tirar o saldo, mudar o status e liberar as chaves). A transação garante o principio "tudo ou nada" garantindo o SOLID. As variáveis @v_idCliente, @v_status, @v_total e @v_saldo guardam os valores lidos para serem usados nas verificações seguintes no uso CALL sp_pagar_pedido(5); ||

  VIEW vw_vendas_detalhadas - Junta Pedido, Cliente, Item_Pedido, Jogo e Desenvolvedora e mostra uma linha para cada item vendido. Foi criada para simplificar uma consulta de cinco tabelas que o atendimento usa bastante, e mostra só as colunas necessárias (sem CPF, e-mail ou senha do cliente) || VIEW vw_catalogo_jogos - Mostra o catalogo com desenvolvedora, preço, classificação, jogo base (quando é dlc) e todas as categorias do jogo em uma coluna só (GROUP_CONCAT junta vários valores em uma única linha)

-----------------------------------------------------------------------------------------------------------------------
Implementações extras:

Possui uma geração automática da chave de ativação no pagamento com uso do UUID() || Procedure com transação, travas de linha (FOR UPDATE) e ROLLBACK em cada falha de verificação (SOLID) || Dois triggers (INSERT e DELETE) para manter o valorTotal sempre correto || Auto-relacionamento para as DLCs, usado em consultas e na view do catalogo || Consulta com LEFT JOIN e IS NULL (clientes sem pedidos) e relatórios com GROUP BY, HAVING e GROUP_CONCAT || Senha dos clientes guardada com hash (SHA2) - criptografia || CHECK para regras de negócio e ON DELETE CASCADE / SET NULL para manter a integridade ao remover registros

-----------------------------------------------------------------------------------------------------------------------

OBS: em algumas partes do código foram utilizados métodos para arredondar valores, então isso pode afetar o resultado final quando for testar
