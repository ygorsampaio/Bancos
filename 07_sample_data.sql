-- =============================================================================
--  07_sample_data.sql
--  Dados de exemplo para desenvolvimento e testes
--
--  Esse arquivo cria um cenário realista pra você poder testar o sistema
--  sem precisar cadastrar tudo do zero. Inclui:
--    - 10 funcionários (4 dentistas + 6 de apoio)
--    - 50 pacientes com endereços reais de bairros de Recife
--    - Telefones, anamneses e alergias
--    - Consultas passadas, de hoje e futuras
--    - Pagamentos e parcelamentos
--    - Evoluções clínicas no prontuário
--    - Planos de tratamento com itens
--    - Receitas e atestados
--    - Lotes de materiais e movimentos de estoque
--    - Notificações e retornos programados
--
--  IMPORTANTE: execute SOMENTE em ambiente de desenvolvimento.
--  Esses dados são completamente fictícios.
--
--  Obs: os triggers estão ativos, então ao inserir os pacientes,
--  os prontuários e odontogramas são criados automaticamente!
-- =============================================================================


-- =============================================================================
--  FUNCIONÁRIOS
--
--  Criei 10 funcionários: 4 dentistas e 6 de apoio administrativo/clínico.
--  Os endereços usam ruas e bairros reais de Recife.
-- =============================================================================

INSERT INTO funcionarios (
    clinica_id, cargo_id, nome_completo, cpf,
    data_nascimento, sexo, email, telefone,
    logradouro, numero, bairro, cidade, estado, cep,
    data_admissao, salario, turno, usuario_sistema
) VALUES
-- Recepcionistas
(1, 4, 'Juliana Cavalcanti Santos',     '123.456.789-01',
 '1990-03-12', 'F', 'juliana.santos@odontoclinica.com.br',   '(81) 99111-2233',
 'Rua do Riachuelo', '45', 'Santo Antonio', 'Recife', 'PE', '50050-180',
 '2020-01-06', 2800.00, 'INTEGRAL', 'juliana.c'),

(1, 4, 'Marcos Vinicius Albuquerque',   '234.567.890-12',
 '1985-07-22', 'M', 'marcos.albuquerque@odontoclinica.com.br','(81) 99222-3344',
 'Rua da Aurora', '200', 'Boa Vista', 'Recife', 'PE', '50050-090',
 '2019-05-13', 2800.00, 'INTEGRAL', 'marcos.v'),

-- Gerente
(1, 5, 'Patricia Melo Barros',           '345.678.901-23',
 '1982-11-05', 'F', 'patricia.barros@odontoclinica.com.br',  '(81) 99333-4455',
 'Av. Agamenon Magalhaes', '1500', 'Aflitos', 'Recife', 'PE', '52010-010',
 '2018-08-01', 5500.00, 'INTEGRAL', 'patricia.b'),

-- Dentistas (cargo 1)
(1, 1, 'Dr. Rafael Augusto Medeiros',   '456.789.012-34',
 '1979-02-18', 'M', 'rafael.medeiros@odontoclinica.com.br',  '(81) 99444-5566',
 'Rua da Saudade', '30', 'Gracas', 'Recife', 'PE', '52011-050',
 '2018-08-01', 9500.00, 'INTEGRAL', 'rafael.m'),

(1, 1, 'Dra. Fernanda Lima Cavalcante', '567.890.123-45',
 '1984-09-30', 'F', 'fernanda.cavalcante@odontoclinica.com.br','(81) 99555-6677',
 'Rua Benfica', '80', 'Madalena', 'Recife', 'PE', '50720-001',
 '2019-03-01', 9200.00, 'MANHA', 'fernanda.c'),

(1, 1, 'Dr. Thiago Nascimento Costa',   '678.901.234-56',
 '1988-06-14', 'M', 'thiago.costa@odontoclinica.com.br',     '(81) 99666-7788',
 'Av. Conselheiro Aguiar', '890', 'Boa Viagem', 'Recife', 'PE', '51020-001',
 '2021-02-15', 8800.00, 'TARDE', 'thiago.n'),

(1, 1, 'Dra. Camila Sousa Ferreira',   '789.012.345-67',
 '1991-12-08', 'F', 'camila.ferreira@odontoclinica.com.br',  '(81) 99777-8899',
 'Rua Prof. Jose Brandao', '55', 'Casa Forte', 'Recife', 'PE', '52061-150',
 '2022-06-01', 8500.00, 'INTEGRAL', 'camila.f'),

-- Auxiliar
(1, 2, 'Roberta Guimaraes Lins',        '890.123.456-78',
 '1995-04-25', 'F', 'roberta.lins@odontoclinica.com.br',     '(81) 99888-9900',
 'Rua Padre Roma', '120', 'Varzea', 'Recife', 'PE', '50741-100',
 '2021-09-01', 2200.00, 'INTEGRAL', 'roberta.g'),

-- TSB
(1, 3, 'Anderson Jose Pereira',          '901.234.567-89',
 '1993-08-17', 'M', 'anderson.pereira@odontoclinica.com.br', '(81) 99000-1122',
 'Av. Norte Miguel Arraes', '600', 'Norte', 'Recife', 'PE', '52170-000',
 '2020-04-01', 2600.00, 'INTEGRAL', 'anderson.p'),

-- Financeiro
(1, 9, 'Larissa Figueiredo Moura',       '012.345.678-90',
 '1997-01-09', 'F', 'larissa.moura@odontoclinica.com.br',    '(81) 91011-2233',
 'Rua Coronel Fabriciano', '34', 'Torre', 'Recife', 'PE', '50710-070',
 '2023-01-03', 2400.00, 'INTEGRAL', 'larissa.m');


-- =============================================================================
--  DENTISTAS
--
--  Vincula os funcionários dentistas ao cadastro de dentistas, com CRO,
--  percentual de comissão e cor na agenda visual.
--
--  A cor_agenda segue o padrão HEX — cada dentista tem uma cor diferente
--  pra aparecer na agenda semanal com visual diferenciado.
-- =============================================================================

INSERT INTO dentistas (funcionario_id, cro_numero, cro_estado, comissao_percentual, cor_agenda) VALUES
(4, 'PE-12345', 'PE', 30.00, '#3B82F6'),  -- Rafael   → azul
(5, 'PE-23456', 'PE', 30.00, '#10B981'),  -- Fernanda → verde
(6, 'PE-34567', 'PE', 28.00, '#F59E0B'),  -- Thiago   → amarelo
(7, 'PE-45678', 'PE', 28.00, '#EF4444'); -- Camila   → vermelho

-- Especialidades de cada dentista
-- Cada dentista tem uma especialidade principal e pode ter outras secundárias
INSERT INTO dentista_especialidades (dentista_id, especialidade_id, principal) VALUES
(1, 2, TRUE),  (1, 1, FALSE), (1, 8, FALSE),  -- Rafael: Endodontia (principal), Clinica Geral, Cirurgia
(2, 4, TRUE),  (2, 9, FALSE),                  -- Fernanda: Ortodontia (principal), Estetica
(3, 5, TRUE),  (3, 8, FALSE),                  -- Thiago: Implantodontia (principal), Cirurgia
(4, 7, TRUE),  (4, 1, FALSE), (4, 3, FALSE);   -- Camila: Odontopediatria (principal), Clinica Geral, Periodontia

-- Disponibilidade semanal (dia_semana: 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex, 6=Sab)
INSERT INTO dentista_disponibilidade (dentista_id, dia_semana, hora_inicio, hora_fim, sala_id) VALUES
-- Rafael: segunda a sexta, manhã e tarde, sala 1
(1,1,'08:00','12:00',1),(1,1,'13:30','18:00',1),
(1,2,'08:00','12:00',1),(1,2,'13:30','18:00',1),
(1,3,'08:00','12:00',1),(1,3,'13:30','18:00',1),
(1,4,'08:00','12:00',1),(1,4,'13:30','18:00',1),
(1,5,'08:00','12:00',1),(1,5,'13:30','17:00',1),
-- Fernanda: segunda a sexta, só manhã, sala 2
(2,1,'08:00','12:30',2),(2,2,'08:00','12:30',2),
(2,3,'08:00','12:30',2),(2,4,'08:00','12:30',2),(2,5,'08:00','11:00',2),
-- Thiago: segunda a sexta, só tarde, sala 3
(3,1,'13:00','18:30',3),(3,2,'13:00','18:30',3),
(3,3,'13:00','18:30',3),(3,4,'13:00','18:30',3),(3,5,'13:00','17:00',3),
-- Camila: segunda a sexta integral + sábado manhã, sala 1 e 3
(4,1,'08:00','18:00',1),(4,2,'08:00','18:00',3),
(4,3,'08:00','18:00',1),(4,4,'08:00','18:00',3),
(4,5,'08:00','12:00',1),(4,6,'08:00','11:00',1);


-- =============================================================================
--  PACIENTES
--
--  50 pacientes fictícios com nomes, CPFs e endereços em bairros reais
--  de Recife. Variei perfis: jovens, adultos, idosos, com e sem convênio,
--  de diferentes bairros.
--
--  OBS: ao inserir cada paciente, o trigger trg_criar_prontuario dispara
--  automaticamente e cria o prontuário + 32 dentes no odontograma.
-- =============================================================================

INSERT INTO pacientes (
    clinica_id, nome_completo, cpf, data_nascimento, sexo,
    estado_civil, profissao,
    logradouro, numero, bairro, cidade, estado, cep,
    email, convenio_id, como_conheceu
) VALUES
(1,'Ana Clara Rodrigues Lima',       '111.111.111-01','1992-05-14','F','SOLTEIRO',   'Professora',
 'Av. Boa Viagem','2300','Boa Viagem','Recife','PE','51020-001','anaclararodrigues@gmail.com',2,'Google'),

(1,'Bruno Henrique Souza',           '222.222.222-02','1988-11-22','M','CASADO',     'Engenheiro',
 'Rua Padre Carapuceiro','500','Boa Viagem','Recife','PE','51020-280','brunohenrique.souza@hotmail.com',1,'Indicacao'),

(1,'Carla Beatriz Ferreira',         '333.333.333-03','1975-03-08','F','DIVORCIADO', 'Enfermeira',
 'Rua Benfica','200','Madalena','Recife','PE','50720-001','carlabeatriz.ferreira@gmail.com',NULL,'Instagram'),

(1,'Diego Mendes Oliveira',          '444.444.444-04','2001-07-19','M','SOLTEIRO',   'Estudante',
 'Rua da Aurora','45','Boa Vista','Recife','PE','50050-090','diegomendes01@gmail.com',NULL,'Instagram'),

(1,'Elaine Cristina Moraes',         '555.555.555-05','1983-12-01','F','CASADO',     'Advogada',
 'Av. Cruz Cabuga','1200','Santo Amaro','Recife','PE','50040-000','elaine.moraes@outlook.com',3,'Indicacao'),

(1,'Felipe Augusto Cardoso',         '666.666.666-06','1995-09-25','M','SOLTEIRO',   'Analista de Sistemas',
 'Rua Real da Torre','340','Madalena','Recife','PE','50710-000','felipeacardoso@gmail.com',NULL,'Google'),

(1,'Giovana Santana Barbosa',        '777.777.777-07','1968-04-17','F','CASADO',     'Medica',
 'Rua Joaquim Nabuco','88','Gracas','Recife','PE','52011-000','giovana.barbosa@yahoo.com.br',4,'Passagem pela rua'),

(1,'Heitor Vasconcelos Nunes',       '888.888.888-08','1980-08-30','M','CASADO',     'Contador',
 'Rua do Hospicio','120','Boa Vista','Recife','PE','50060-080','heitorvnunes@gmail.com',1,'Facebook'),

(1,'Isabela Mendonca Castro',        '999.999.999-09','2005-02-28','F','SOLTEIRO',   'Estudante',
 'Av. Caxanga','500','Caxanga','Recife','PE','50781-000','isabela.mendonca05@gmail.com',NULL,'Indicacao'),

(1,'Jonas Pereira Alves',            '100.000.000-10','1972-06-12','M','CASADO',     'Policial Militar',
 'Rua Frei Matias Teves','60','Afogados','Recife','PE','50870-000','jonas.alves72@gmail.com',5,'Indicacao'),

(1,'Karla Cristiane Melo',           '110.000.000-11','1990-10-05','F','SOLTEIRO',   'Designer',
 'Rua Dona Maria Cesar','150','Derby','Recife','PE','52010-200','karlacmelo@gmail.com',NULL,'Google'),

(1,'Leonardo Farias Rocha',          '120.000.000-12','1986-01-18','M','CASADO',     'Arquiteto',
 'Rua Padre Ingles','200','Soledade','Recife','PE','50050-010','leofarias.arq@gmail.com',2,'Indicacao'),

(1,'Marina Lopes Tavares',           '130.000.000-13','1998-07-07','F','SOLTEIRO',   'Farmaceutica',
 'Av. Agamenon Magalhaes','800','Espinheiro','Recife','PE','52021-000','marina.ltavares@outlook.com',6,'Google'),

(1,'Nelson Vieira Gomes',            '140.000.000-14','1962-03-23','M','VIUVO',      'Aposentado',
 'Rua Dr. Nilo Dornelas Camara','55','Jardim Sao Paulo','Recife','PE','52070-460','nelsonvgomes@gmail.com',NULL,'Indicacao'),

(1,'Olivia Nascimento Silva',        '150.000.000-15','1994-11-14','F','CASADO',     'Nutricionista',
 'Rua das Gracas','400','Gracas','Recife','PE','52011-090','olivia.n.silva@gmail.com',3,'Instagram'),

(1,'Pedro Henrique Araujo',          '160.000.000-16','2003-04-02','M','SOLTEIRO',   'Estudante',
 'Rua Dom Bosco','30','Iputinga','Recife','PE','50671-000','pedroharaujo03@gmail.com',NULL,'Indicacao'),

(1,'Quesia Linhares Freitas',        '170.000.000-17','1979-09-19','F','DIVORCIADO', 'Assistente Social',
 'Rua do Riachuelo','320','Santo Antonio','Recife','PE','50050-180','quesia.freitas@yahoo.com.br',1,'Facebook'),

(1,'Rodrigo Cesar Borges',           '180.000.000-18','1991-05-31','M','SOLTEIRO',   'Desenvolvedor Web',
 'Av. Beira Rio','700','Casa Forte','Recife','PE','52061-000','rodrigocborges@gmail.com',NULL,'Google'),

(1,'Sandra Patricia Azevedo',        '190.000.000-19','1977-12-25','F','CASADO',     'Pedagoga',
 'Rua Otavio Kelly','88','Tamarineira','Recife','PE','52050-060','sandraazevedo77@hotmail.com',4,'Indicacao'),

(1,'Tulio Mendonca Cavalcanti',      '200.000.000-20','1985-08-08','M','CASADO',     'Dentista',
 'Rua Prof. Jose Brandao','200','Casa Forte','Recife','PE','52061-150','tulio.mendo@gmail.com',2,'Indicacao'),

(1,'Ursula Fonseca Magalhaes',       '210.000.000-21','2000-02-14','F','SOLTEIRO',   'Estudante de Medicina',
 'Av. Conselheiro Aguiar','1500','Boa Viagem','Recife','PE','51020-001','ursula.fonseca@gmail.com',NULL,'Instagram'),

(1,'Vinicius Teixeira Barbosa',      '220.000.000-22','1973-10-28','M','CASADO',     'Servidor Publico',
 'Rua Padre Lemos','60','Afogados','Recife','PE','50870-100','vinicius.tb73@gmail.com',5,'Indicacao'),

(1,'Wanessa Cordeiro Lima',          '230.000.000-23','1996-06-16','F','SOLTEIRO',   'Jornalista',
 'Rua da Saudade','30','Gracas','Recife','PE','52011-050','wanessa.cordeiro@outlook.com',NULL,'Google'),

(1,'Xisto Almeida Correia',          '240.000.000-24','1955-01-04','M','CASADO',     'Comerciante',
 'Rua 15 de Novembro','450','Boa Vista','Recife','PE','50050-000','xistoalmeida55@gmail.com',6,'Passagem pela rua'),

(1,'Yasmin Souza Pimentel',          '250.000.000-25','2007-08-22','F','SOLTEIRO',   'Estudante',
 'Av. Caxanga','1000','Varzea','Recife','PE','50741-000','yasmin.pimentel07@gmail.com',NULL,'Indicacao'),

(1,'Alexandre Ramos Duarte',         '260.000.000-26','1969-04-15','M','CASADO',     'Medico Cardiologista',
 'Rua Joaquim Nabuco','55','Gracas','Recife','PE','52011-000','alexandreduarte@gmail.com',2,'Indicacao'),

(1,'Beatriz Moreira Cunha',          '270.000.000-27','1993-09-12','F','CASADO',     'Fisioterapeuta',
 'Rua do Futuro','220','Rosarinho','Recife','PE','52041-000','beatrizmoreira93@gmail.com',3,'Instagram'),

(1,'Cesar Henrique Brito',           '280.000.000-28','1987-03-03','M','CASADO',     'Administrador',
 'Rua Padre Champagnat','80','Aflitos','Recife','PE','52010-040','cesarbrito87@hotmail.com',1,'Google'),

(1,'Debora Lima Menezes',            '290.000.000-29','2004-11-30','F','SOLTEIRO',   'Estudante',
 'Av. Norte Miguel Arraes','400','Arruda','Recife','PE','52170-000','debora.menezes04@gmail.com',NULL,'Indicacao'),

(1,'Eduardo Sampaio Torres',         '300.000.000-30','1978-07-07','M','DIVORCIADO', 'Representante Comercial',
 'Av. Agamenon Magalhaes','2000','Parnamirim','Recife','PE','52060-000','eduardo.sampaio78@gmail.com',4,'Facebook'),

(1,'Flavia Regina Nogueira',         '310.000.000-31','1984-02-19','F','CASADO',     'Economista',
 'Rua Joaquim Nabuco','200','Gracas','Recife','PE','52011-000','flavianogueira84@outlook.com',2,'Indicacao'),

(1,'Gustavo Andrade Peixoto',        '320.000.000-32','1999-05-06','M','SOLTEIRO',   'Estudante de Direito',
 'Rua da Gloria','100','Boa Vista','Recife','PE','50060-000','gustavoapeixoto@gmail.com',NULL,'Google'),

(1,'Helena Cristina Freire',         '330.000.000-33','1971-08-21','F','CASADO',     'Professora Universitaria',
 'Av. Rosa e Silva','500','Aflitos','Recife','PE','52050-020','helenafreire71@gmail.com',5,'Indicacao'),

(1,'Ivan Luiz Coelho',               '340.000.000-34','1982-12-10','M','CASADO',     'Tecnico Eletrico',
 'Rua Arnobio Marques','120','Santo Amaro','Recife','PE','50100-000','ivancoelho82@hotmail.com',1,'Passagem pela rua'),

(1,'Juliana Monteiro Barros',        '350.000.000-35','1997-04-28','F','SOLTEIRO',   'Nutricionista',
 'Rua Benfica','310','Madalena','Recife','PE','50720-001','julianamonteiro97@gmail.com',NULL,'Instagram'),

(1,'Kleber Fonseca Nascimento',      '360.000.000-36','1975-10-15','M','CASADO',     'Policial Civil',
 'Rua Padre Carapuceiro','200','Boa Viagem','Recife','PE','51020-280','klebernascimento@gmail.com',4,'Indicacao'),

(1,'Luciana Pacheco Braga',          '370.000.000-37','1989-01-24','F','CASADO',     'Psicologa',
 'Rua do Principe','88','Boa Vista','Recife','PE','50050-110','lucianabraga89@outlook.com',3,'Google'),

(1,'Matheus Ribeiro Alencar',        '380.000.000-38','2002-06-03','M','SOLTEIRO',   'Estudante',
 'Rua Padre Ingles','50','Soledade','Recife','PE','50050-010','matheus.alencar02@gmail.com',NULL,'Indicacao'),

(1,'Nathalia Souza Bandeira',        '390.000.000-39','1986-09-09','F','DIVORCIADO', 'Medica Pediatra',
 'Av. Boa Viagem','1200','Boa Viagem','Recife','PE','51020-001','nathalia.bandeira@gmail.com',2,'Indicacao'),

(1,'Orlando Henrique Dias',          '400.000.000-40','1965-03-31','M','CASADO',     'Empresario',
 'Rua Visconde de Jequitinhonha','400','Boa Vista','Recife','PE','50050-140','orlandodias65@gmail.com',6,'Passagem pela rua'),

(1,'Patricia Holanda Lima',          '410.000.000-41','1993-07-18','F','CASADO',     'Enfermeira',
 'Rua Padre Lemos','150','Afogados','Recife','PE','50870-100','patriciahl@gmail.com',1,'Facebook'),

(1,'Quintino Araujo Melo',           '420.000.000-42','1958-11-12','M','CASADO',     'Aposentado',
 'Av. Rui Barbosa','500','Gracas','Recife','PE','52011-080','quintino.melo58@yahoo.com.br',5,'Indicacao'),

(1,'Rachel Abreu Formiga',           '430.000.000-43','2001-04-04','F','SOLTEIRO',   'Estudante de Psicologia',
 'Rua Dom Bosco','200','Iputinga','Recife','PE','50671-000','rachelformiga01@gmail.com',NULL,'Instagram'),

(1,'Savio Neves Cavalcante',         '440.000.000-44','1980-02-16','M','CASADO',     'Piloto de Aviao',
 'Av. Domingos Ferreira','2000','Boa Viagem','Recife','PE','51020-030','savio.cavalcante@gmail.com',2,'Indicacao'),

(1,'Tatiana Cristina Vieira',        '450.000.000-45','1990-08-27','F','CASADO',     'Biomedica',
 'Rua Real da Torre','100','Madalena','Recife','PE','50710-000','tatiana.vieira90@gmail.com',3,'Google'),

(1,'Urbano Felix Dantas',            '460.000.000-46','1967-05-10','M','CASADO',     'Comerciante',
 'Rua do Riachuelo','400','Santo Antonio','Recife','PE','50050-180','urbanodantas@hotmail.com',4,'Passagem pela rua'),

(1,'Vanessa Karoline Moura',         '470.000.000-47','1995-12-22','F','SOLTEIRO',   'Relacoes Publicas',
 'Rua Visconde de Jequitinhonha','100','Boa Vista','Recife','PE','50050-140','vanessa.karoline@gmail.com',NULL,'Instagram'),

(1,'William Brandao Santos',         '480.000.000-48','1976-07-04','M','CASADO',     'Tenente do Exercito',
 'Rua do Futuro','300','Rosarinho','Recife','PE','52041-000','williambsantos76@gmail.com',1,'Indicacao'),

(1,'Xenia Cavalcanti Belo',          '490.000.000-49','2006-10-14','F','SOLTEIRO',   'Estudante',
 'Av. Caxanga','750','Caxanga','Recife','PE','50781-000','xenia.belo06@gmail.com',NULL,'Indicacao'),

(1,'Yuri Farias Pinheiro',           '500.000.000-50','1988-03-26','M','CASADO',     'Geografo',
 'Rua Padre Champagnat','120','Aflitos','Recife','PE','52010-040','yuri.farias88@gmail.com',6,'Google');


-- =============================================================================
--  TELEFONES DOS PACIENTES
--
--  Variei os tipos: alguns têm WhatsApp separado, outros têm residencial.
--  O campo "principal" define qual número aparece primeiro na busca.
-- =============================================================================

INSERT INTO paciente_telefones (paciente_id, tipo, numero, principal) VALUES
(1,'CELULAR','(81) 99101-1111',TRUE),(1,'WHATSAPP','(81) 99101-1111',FALSE),
(2,'CELULAR','(81) 99202-2222',TRUE),(2,'RESIDENCIAL','(81) 3222-2222',FALSE),
(3,'CELULAR','(81) 99303-3333',TRUE),(3,'WHATSAPP','(81) 99303-3333',FALSE),
(4,'CELULAR','(81) 99404-4444',TRUE),
(5,'CELULAR','(81) 99505-5555',TRUE),(5,'COMERCIAL','(81) 3555-5555',FALSE),
(6,'CELULAR','(81) 99606-6666',TRUE),(6,'WHATSAPP','(81) 99606-6666',FALSE),
(7,'CELULAR','(81) 99707-7777',TRUE),(7,'RESIDENCIAL','(81) 3777-7777',FALSE),
(8,'CELULAR','(81) 99808-8888',TRUE),
(9,'CELULAR','(81) 99909-9999',TRUE),(9,'WHATSAPP','(81) 99909-9999',FALSE),
(10,'CELULAR','(81) 99010-0000',TRUE),
(11,'CELULAR','(81) 99111-2200',TRUE),(11,'WHATSAPP','(81) 99111-2200',FALSE),
(12,'CELULAR','(81) 99122-3300',TRUE),
(13,'CELULAR','(81) 99133-4400',TRUE),(13,'WHATSAPP','(81) 99133-4400',FALSE),
(14,'CELULAR','(81) 99144-5500',TRUE),(14,'RESIDENCIAL','(81) 3144-5500',FALSE),
(15,'CELULAR','(81) 99155-6600',TRUE),
(16,'CELULAR','(81) 99166-7700',TRUE),(16,'WHATSAPP','(81) 99166-7700',FALSE),
(17,'CELULAR','(81) 99177-8800',TRUE),
(18,'CELULAR','(81) 99188-9900',TRUE),(18,'WHATSAPP','(81) 99188-9900',FALSE),
(19,'CELULAR','(81) 99199-0000',TRUE),
(20,'CELULAR','(81) 99200-1100',TRUE),(20,'COMERCIAL','(81) 3200-1100',FALSE),
(21,'CELULAR','(81) 99211-2200',TRUE),(21,'WHATSAPP','(81) 99211-2200',FALSE),
(22,'CELULAR','(81) 99222-3300',TRUE),
(23,'CELULAR','(81) 99233-4400',TRUE),(23,'WHATSAPP','(81) 99233-4400',FALSE),
(24,'CELULAR','(81) 99244-5500',TRUE),
(25,'CELULAR','(81) 99255-6600',TRUE),(25,'WHATSAPP','(81) 99255-6600',FALSE),
(26,'CELULAR','(81) 99266-7700',TRUE),(26,'COMERCIAL','(81) 3266-7700',FALSE),
(27,'CELULAR','(81) 99277-8800',TRUE),
(28,'CELULAR','(81) 99288-9900',TRUE),(28,'WHATSAPP','(81) 99288-9900',FALSE),
(29,'CELULAR','(81) 99299-0000',TRUE),
(30,'CELULAR','(81) 99300-1100',TRUE);
