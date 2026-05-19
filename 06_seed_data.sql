-- =============================================================================
--  06_seed_data.sql
--  Dados iniciais obrigatórios para o funcionamento do sistema
--
--  Seed data são os dados que o sistema precisa pra funcionar desde o
--  primeiro dia — antes de qualquer paciente ser cadastrado.
--  São diferentes dos dados de exemplo (07_sample_data.sql), que servem
--  só pra desenvolvimento e testes.
--
--  Aqui estão:
--    - Dados da clínica
--    - Salas / consultórios
--    - Especialidades odontológicas (CFO)
--    - Catálogo de procedimentos com códigos TUSS e CBHPM
--    - Cargos dos funcionários
--    - Categorias de materiais
--    - Convênios reais
--    - Fornecedores
--    - Catálogo de materiais/insumos
--
--  IMPORTANTE: execute esse arquivo depois de 05_triggers.sql.
--  Os triggers já estão ativos, então qualquer INSERT aqui também
--  será auditado automaticamente.
-- =============================================================================


-- =============================================================================
--  CLÍNICA
--
--  Dados da clínica principal. Se você for adaptar esse projeto pra uma
--  clínica real, substitua essas informações aqui.
--
--  O CNPJ, CRO e endereço abaixo são fictícios.
-- =============================================================================

INSERT INTO clinica (
    razao_social, nome_fantasia, cnpj, cro_pj,
    email, site,
    logradouro, numero, bairro, cidade, estado, cep,
    telefone_principal, whatsapp,
    horario_abertura, horario_fechamento, intervalo_consulta
) VALUES (
    'OdontoRecife Servicos Odontologicos LTDA',
    'OdontoRecife',
    '12.345.678/0001-90',
    'CRO-PE 1234',
    'contato@odontoclinica.com.br',
    'https://www.odontoclinica.com.br',
    'Rua Padre Carapuceiro', '100',
    'Boa Viagem', 'Recife', 'PE', '51020-280',
    '(81) 3333-4444',
    '(81) 99999-8888',
    '08:00', '19:00', 30
);


-- =============================================================================
--  SALAS / CONSULTÓRIOS
--
--  Cada sala pode ter um tipo de atendimento diferente. Separei pra que
--  o sistema de agendamento consiga evitar dois procedimentos na mesma sala
--  ao mesmo tempo — assim como evita conflito no horário do dentista.
-- =============================================================================

INSERT INTO salas (clinica_id, nome, descricao) VALUES
    (1, 'Consultorio 1',        'Clinica geral e endodontia'),
    (1, 'Consultorio 2',        'Ortodontia e protese'),
    (1, 'Consultorio 3',        'Implantodontia e cirurgia'),
    (1, 'Sala de Raio-X',       'Radiografias e diagnostico por imagem'),
    (1, 'Sala de Esterilizacao','Processamento e esterilizacao de instrumentos'),
    (1, 'Sala de Espera',       'Recepcao e espera de pacientes');


-- =============================================================================
--  ESPECIALIDADES ODONTOLÓGICAS
--
--  Lista das especialidades reconhecidas pelo CFO (Conselho Federal de
--  Odontologia). Essas são as especialidades "oficiais" — existem 22 no total,
--  listei as mais comuns em clínicas gerais de Recife.
-- =============================================================================

INSERT INTO especialidades (nome, descricao) VALUES
    ('Clinica Geral',            'Atendimento odontologico geral'),
    ('Endodontia',               'Tratamento de canais radiculares'),
    ('Periodontia',              'Doencas gengivais e do periodonto'),
    ('Ortodontia',               'Aparelhos e correcao da ma-oclusao'),
    ('Implantodontia',           'Implantes dentarios osseointegrados'),
    ('Protese Dentaria',         'Coroas, pontes e dentaduras'),
    ('Odontopediatria',          'Atendimento odontologico infantil'),
    ('Cirurgia Bucomaxilofacial','Extracoes complexas e cirurgias'),
    ('Estetica Dental',          'Facetas, clareamento e harmonizacao'),
    ('Dentistica',               'Restauracoes e tratamentos esteticos'),
    ('Radiologia Odontologica',  'Diagnostico por imagem'),
    ('Saude Coletiva',           'Epidemiologia e saude bucal coletiva'),
    ('Odontologia do Esporte',   'Protecao e cuidados no esporte'),
    ('Odontogeriatria',          'Atendimento a pacientes idosos');


-- =============================================================================
--  PROCEDIMENTOS
--
--  Esse é o catálogo de procedimentos da clínica. Cada procedimento tem:
--    - especialidade_id: a qual especialidade pertence
--    - codigo_tuss: código da Terminologia Unificada da Saúde Suplementar (ANS)
--    - codigo_cbhpm: código da tabela CBHPM (usada por alguns convênios)
--    - duracao_minutos: tempo médio do procedimento (usado na agenda)
--    - valor_base: preço particular (convênios têm tabela própria)
--    - requer_rx: se precisa de radiografia antes
--    - requer_anestesia: se usa anestésico (impacta estoque)
--
--  Os valores são baseados em tabelas de referência de Recife/PE (2024).
--  Ajuste conforme a realidade da sua clínica.
-- =============================================================================

INSERT INTO procedimentos (
    especialidade_id, codigo_tuss, nome, descricao,
    duracao_minutos, valor_base, requer_rx, requer_anestesia
) VALUES

-- -------------------------------------------------------------------------
-- CLINICA GERAL
-- -------------------------------------------------------------------------
(1, '40101010', 'Consulta/Exame Clinico',
    'Avaliacao clinica geral com diagnostico', 30, 120.00, FALSE, FALSE),
(1, '40101029', 'Retorno / Revisao',
    'Consulta de acompanhamento', 20, 80.00, FALSE, FALSE),
(1, '40101045', 'Urgencia Odontologica',
    'Atendimento de urgencia e dor aguda', 30, 150.00, FALSE, TRUE),

-- -------------------------------------------------------------------------
-- DENTISTICA / RESTAURACOES
-- -------------------------------------------------------------------------
(10, '40201013', 'Restauracao Resina 1 Face',
    'Restauracao em resina composta - 1 face', 40, 180.00, FALSE, TRUE),
(10, '40201021', 'Restauracao Resina 2 Faces',
    'Restauracao em resina composta - 2 faces', 50, 250.00, FALSE, TRUE),
(10, '40201030', 'Restauracao Resina 3+ Faces',
    'Restauracao em resina composta - 3 ou mais faces', 60, 320.00, FALSE, TRUE),
(10, '40201048', 'Restauracao Amalgama',
    'Restauracao em amalgama de prata', 40, 150.00, FALSE, TRUE),
(10, '40201056', 'Restauracao Ionomero de Vidro',
    'Restauracao em cimento de ionomero de vidro', 30, 130.00, FALSE, TRUE),
(10, '40201064', 'Restauracao Provisoria',
    'Restauracao temporaria entre sessoes', 20, 80.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- ENDODONTIA (CANAIS)
-- -------------------------------------------------------------------------
(2, '40301016', 'Tratamento de Canal - Dente Unirradicular',
    'Endodontia em dente com 1 raiz (incisivos, caninos)', 90, 650.00, TRUE, TRUE),
(2, '40301024', 'Tratamento de Canal - Dente Birradicular',
    'Endodontia em dente com 2 raizes (pre-molares)', 120, 850.00, TRUE, TRUE),
(2, '40301032', 'Tratamento de Canal - Dente Multirradicular',
    'Endodontia em dente com 3+ raizes (molares)', 150, 1100.00, TRUE, TRUE),
(2, '40301040', 'Retratamento de Canal',
    'Retratamento endodontico de canal previamente tratado', 120, 900.00, TRUE, TRUE),
(2, '40301059', 'Curativo de Demora',
    'Medicacao intracanal entre sessoes de endodontia', 30, 120.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- PERIODONTIA
-- -------------------------------------------------------------------------
(3, '40401011', 'Raspagem e Alisamento Radicular (por sextante)',
    'RAR subgengival por sextante', 60, 280.00, FALSE, TRUE),
(3, '40401020', 'Profilaxia / Limpeza',
    'Remocao de tartaro e polimento dental', 40, 150.00, FALSE, FALSE),
(3, '40401038', 'Curetagem Subgengival',
    'Curetagem periodontal', 60, 320.00, FALSE, TRUE),
(3, '40401046', 'Gengivoplastia',
    'Cirurgia plastica gengival', 90, 800.00, FALSE, TRUE),
(3, '40401054', 'Enxerto Gengival Livre',
    'Enxerto de tecido gengival para recobrimento radicular', 120, 1200.00, TRUE, TRUE),
(3, '40401062', 'Irrigacao Subgengival',
    'Irrigacao com antissepticos subgengivais', 20, 80.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- CIRURGIA
-- -------------------------------------------------------------------------
(8, '40501017', 'Exodontia Simples',
    'Extracao dental simples', 30, 200.00, FALSE, TRUE),
(8, '40501025', 'Exodontia Complexa / Siso',
    'Extracao de dente incluso ou semi-incluso', 60, 450.00, TRUE, TRUE),
(8, '40501033', 'Frenectomia Lingual',
    'Cirurgia de freio lingual (lingua presa)', 45, 600.00, FALSE, TRUE),
(8, '40501041', 'Frenectomia Labial',
    'Cirurgia de freio labial superior', 45, 500.00, FALSE, TRUE),
(8, '40501050', 'Apicectomia',
    'Resseccao cirurgica do apice radicular', 90, 900.00, TRUE, TRUE),
(8, '40501068', 'Biopsia Oral',
    'Coleta de fragmento para exame anatomopatologico', 45, 400.00, FALSE, TRUE),

-- -------------------------------------------------------------------------
-- IMPLANTODONTIA
-- -------------------------------------------------------------------------
(5, '40601013', 'Instalacao de Implante Osseointegrado',
    'Colocacao cirurgica do implante de titanio', 90, 2800.00, TRUE, TRUE),
(5, '40601021', 'Reabertura de Implante',
    'Segunda cirurgia para exposicao do implante apos osseointegrar', 30, 450.00, FALSE, TRUE),
(5, '40601030', 'Coroa sobre Implante (metal-ceramica)',
    'Coroa protetica sobre implante osseointegrado', 60, 2200.00, FALSE, FALSE),
(5, '40601048', 'Enxerto Osseo',
    'Enxerto osseo para preparar area do implante', 120, 1800.00, TRUE, TRUE),
(5, '40601056', 'Levantamento de Seio Maxilar',
    'Cirurgia para aumento do seio maxilar - permite implante superior', 120, 2500.00, TRUE, TRUE),

-- -------------------------------------------------------------------------
-- PROTESE DENTARIA
-- -------------------------------------------------------------------------
(6, '40701010', 'Coroa Metalo-Ceramica',
    'Coroa de porcelana sobre estrutura metalica', 60, 1800.00, FALSE, FALSE),
(6, '40701028', 'Coroa Total em Ceramica Pura',
    'Coroa em zirconia ou e.max - maior estetica', 60, 2400.00, FALSE, FALSE),
(6, '40701036', 'Protese Parcial Removivel (por arco)',
    'Protese parcial removivel em metal e resina', 90, 1500.00, FALSE, FALSE),
(6, '40701044', 'Protese Total Superior',
    'Dentadura superior completa', 60, 1800.00, FALSE, FALSE),
(6, '40701052', 'Protese Total Inferior',
    'Dentadura inferior completa', 60, 1800.00, FALSE, FALSE),
(6, '40701060', 'Protese Parcial Fixa (3 elementos)',
    'Ponte fixa com 3 elementos (inclui dente ausente)', 120, 4500.00, FALSE, FALSE),
(6, '40701079', 'Inlay/Onlay Ceramico',
    'Restauracao indireta em ceramica - maior durabilidade', 60, 1600.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- ORTODONTIA
-- -------------------------------------------------------------------------
(4, '40801016', 'Instalacao Aparelho Fixo Metalico',
    'Braquetes metalicos convencionais', 90, 2500.00, TRUE, FALSE),
(4, '40801024', 'Instalacao Aparelho Fixo Estetico',
    'Braquetes ceramicos ou de safira', 90, 3200.00, TRUE, FALSE),
(4, '40801032', 'Manutencao Mensal de Aparelho',
    'Troca de elasricos e ajustes mensais', 30, 200.00, FALSE, FALSE),
(4, '40801040', 'Remocao de Aparelho + Contencao',
    'Remocao dos braquetes e instalacao de contencao', 60, 500.00, FALSE, FALSE),
(4, '40801059', 'Placa Removivel Ortodontica',
    'Aparelho removivel para tratamento e contencao', 30, 600.00, FALSE, FALSE),
(4, '40801067', 'Alinhador Transparente (por fase)',
    'Tratamento com alinhadores invisiveis - cada fase', 30, 800.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- ESTETICA DENTAL
-- -------------------------------------------------------------------------
(9, '40901011', 'Clareamento Dental (consultorio)',
    'Clareamento com LED/laser em sessao no consultorio', 90, 700.00, FALSE, FALSE),
(9, '40901020', 'Clareamento Dental (caseiro)',
    'Moldeira personalizada + gel para uso em casa', 30, 350.00, FALSE, FALSE),
(9, '40901038', 'Faceta de Porcelana (por dente)',
    'Laminado ceramico - fino e altamente estetico', 60, 2000.00, FALSE, FALSE),
(9, '40901046', 'Faceta de Resina Composta (por dente)',
    'Faceta direta em resina - opcao mais acessivel', 60, 600.00, FALSE, FALSE),
(9, '40901054', 'Gengivoplastia Estetica a Laser',
    'Remodelamento gengival com laser de alta potencia', 60, 1200.00, FALSE, TRUE),
(9, '40901062', 'Botox Facial (3 regioes)',
    'Toxina botulinica para bruxismo e harmonizacao facial', 30, 900.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- ODONTOPEDIATRIA
-- -------------------------------------------------------------------------
(7, '41001013', 'Selante Oclusal (por dente)',
    'Aplicacao de selante de fissura preventivo', 20, 80.00, FALSE, FALSE),
(7, '41001021', 'Restauracao Pediatrica Resina',
    'Restauracao em resina em dente deciduo (de leite)', 30, 150.00, FALSE, TRUE),
(7, '41001030', 'Pulpotomia (dente deciduo)',
    'Tratamento de canal parcial em dente de leite', 45, 300.00, FALSE, TRUE),
(7, '41001048', 'Coroa de Aco Pediatrica',
    'Coroa metalica pre-formada para dente de leite', 45, 250.00, FALSE, TRUE),
(7, '41001056', 'Aplicacao de Fluor',
    'Fluoretacao topica com gel ou verniz fluoretado', 20, 60.00, FALSE, FALSE),
(7, '41001064', 'Espacador de Band-Loop',
    'Manutencao de espaco para dente permanente', 30, 350.00, FALSE, FALSE),

-- -------------------------------------------------------------------------
-- RADIOLOGIA
-- -------------------------------------------------------------------------
(11, '41101010', 'Radiografia Periapical',
    'Rx periapical digital por dente - mostra raiz e osso ao redor', 10, 50.00, FALSE, FALSE),
(11, '41101028', 'Radiografia Panoramica',
    'Rx panoramico digital - visao de toda a boca', 10, 150.00, FALSE, FALSE),
(11, '41101036', 'Bite-Wing (interproximal)',
    'Rx bite-wing - detecta caries entre os dentes', 10, 80.00, FALSE, FALSE),
(11, '41101044', 'Tomografia Cone Beam (arco)',
    'CBCT 3D para planejamento de implante e cirurgia', 20, 500.00, FALSE, FALSE),
(11, '41101052', 'Cefalometria',
    'Rx cefalometrico lateral - usado em planejamento ortodontico', 10, 120.00, FALSE, FALSE);


-- =============================================================================
--  CARGOS
-- =============================================================================

INSERT INTO cargos (nome, descricao) VALUES
    ('Dentista',                     'Profissional com registro no CRO'),
    ('Auxiliar de Consultorio Dental','Auxiliar ACD - auxilia o dentista durante atendimentos'),
    ('Tecnico em Saude Bucal',        'TSB - pode realizar procedimentos delegados pelo dentista'),
    ('Recepcionista',                 'Atendimento ao publico, agendamentos e recepcao'),
    ('Gerente Administrativo',        'Gestao administrativa e financeira da clinica'),
    ('Tecnico em Radiologia Dental',  'Realiza exames de imagem odontologica'),
    ('Auxiliar de Limpeza',           'Higienizacao e conservacao das instalacoes'),
    ('Estoquista',                    'Controle de materiais e insumos'),
    ('Financeiro',                    'Controle financeiro, faturamento e cobranca'),
    ('TI / Suporte',                  'Suporte tecnico de sistemas e equipamentos');


-- =============================================================================
--  CATEGORIAS DE MATERIAL
-- =============================================================================

INSERT INTO categorias_material (nome, descricao) VALUES
    ('Materiais Restauradores',           'Resinas, amalgama, ionomero'),
    ('Materiais Endodonticos',            'Limas, cimentos, seladores de canal'),
    ('Materiais de Impressao',            'Alginato, silicone, gesso'),
    ('Materiais Anestesicos',             'Tubetes anestesicos, agulhas e seringas'),
    ('Materiais de Profilaxia',           'Pasta, escova, fio dental, fluor'),
    ('Instrumentais Basicos',             'Espelhos, sondas, pincas, excavadores'),
    ('Instrumentais Rotatorios',          'Brocas, discos, pontas de alta e baixa rotacao'),
    ('EPI e Descartaveis',                'Luvas, mascaras, gorros, babadores'),
    ('Materiais Periodontais',            'Curetas, limas periodontais'),
    ('Materiais Cirurgicos',              'Bisturis, suturas, hemostaticos'),
    ('Materiais Ortodonticos',            'Braquetes, fios, elasricos, bandas'),
    ('Produtos de Limpeza e Esterilizacao','Desinfetantes, embalagens para autoclave'),
    ('Materiais de Radiologia',           'Filmes, aventais de chumbo, protetores'),
    ('Medicamentos',                      'Analgésicos, anti-inflamatórios, antibioticos'),
    ('Material de Escritorio',            'Papelaria, impressao e formularios');


-- =============================================================================
--  CONVÊNIOS
--
--  Listei os principais convênios odontológicos que operam em Recife.
--  Os dados (CNPJ, ANS) são reais e públicos — disponíveis no site da ANS.
--  "Particular" é o convênio fictício pra atendimentos sem plano.
-- =============================================================================

INSERT INTO convenios (nome, razao_social, cnpj, ans_registro, email, telefone) VALUES
    ('Amil Dental',
     'Amil Assistencia Medica Internacional LTDA',
     '29.309.127/0001-79', '326305',
     'credenciamento@amil.com.br', '0800-722-2645'),

    ('Bradesco Dental',
     'Bradesco Saude S.A.',
     '92.693.118/0001-60', '005711',
     'dental@bradescosaude.com.br', '0800-722-0110'),

    ('SulAmerica Odonto',
     'Sul America Companhia de Seguro Saude',
     '01.685.903/0001-16', '006246',
     'odonto@sulamerica.com.br', '0800-722-4848'),

    ('Unimed Odonto',
     'Unimed Odontologia S.A.',
     '03.936.308/0001-24', '421979',
     'odonto@unimed.coop.br', '(81) 3216-2000'),

    ('Hapvida Dental',
     'Hapvida Assistencia Medica LTDA',
     '63.554.067/0001-98', '368253',
     'dental@hapvida.com.br', '(81) 4020-0800'),

    ('Porto Seguro Odonto',
     'Porto Seguro Saude S.A.',
     '90.180.605/0001-02', '382956',
     'odonto@portoseguro.com.br', '0800-727-5858'),

    ('Metlife Sorriso',
     'Metropolitan Life Seguros S.A.',
     '02.102.498/0001-29', '390097',
     'sorriso@metlife.com.br', '0800-730-1717'),

    ('Particular',
     'Atendimento Particular sem Convenio',
     NULL, NULL, NULL, NULL);


-- =============================================================================
--  FORNECEDORES
--
--  Principais distribuidoras de materiais odontológicos que atendem Recife.
--  A NordesteDental (id 7) é local — faz entregas no mesmo dia.
-- =============================================================================

INSERT INTO fornecedores (
    razao_social, nome_fantasia, cnpj,
    email, telefone,
    cidade, estado,
    prazo_entrega_dias, contato_nome
) VALUES
    ('Dental Cremer S.A.',               'Cremer Dental',  '82.641.325/0001-18',
     'vendas@cremer.com.br',        '0800-647-8888', 'Sao Paulo', 'SP', 3, 'Carlos Lima'),

    ('SS White Artigos Dentarios LTDA',  'SS White',       '60.488.004/0001-46',
     'vendas@sswhite.com.br',       '(11) 3611-3600','Sao Paulo', 'SP', 5, 'Ana Ferreira'),

    ('Herpo Produtos Dentarios LTDA',    'Herpo',          '18.488.264/0001-62',
     'comercial@herpo.com.br',      '(11) 4063-1500','Sao Paulo', 'SP', 4, 'Bruno Souza'),

    ('Condor S.A. Industria e Comercio', 'Condor',         '82.978.685/0001-17',
     'distribuidor@condor.ind.br',  '(47) 3361-5959','Sao Bento do Sul', 'SC', 5, 'Fernanda Costa'),

    ('DENTSPLY Brasil LTDA',             'Dentsply Sirona','59.116.800/0001-47',
     'info@dentsply.com.br',        '(11) 5091-4900','Petropolis', 'RJ', 4, 'Paula Melo'),

    ('3M do Brasil LTDA',                '3M Dental',      '45.985.371/0001-08',
     'dental.br@mmm.com',           '0800-729-3300', 'Sumare', 'SP', 5, 'Ricardo Torres'),

    ('Distrib. Nordeste Dental LTDA',    'NordesteDental', '11.234.567/0001-89',
     'pedidos@nordestidental.com.br','(81) 3031-4000','Recife', 'PE', 1, 'Marcia Barros'),

    ('DFL Industria e Comercio S.A.',    'DFL Dental',     '33.421.876/0001-55',
     'vendas@dfl.com.br',           '(21) 3545-5800','Rio de Janeiro', 'RJ', 5, 'Jose Oliveira');


-- =============================================================================
--  MATERIAIS / INSUMOS
--
--  Catálogo de materiais com estoque inicial.
--  Cada material tem:
--    - estoque_minimo: abaixo disso o sistema alerta pra repor
--    - ponto_reposicao: quando atingir isso, já gera o pedido de compra
--
--  Organizei por categoria pra facilitar a leitura.
-- =============================================================================

INSERT INTO materiais (
    categoria_id, fornecedor_preferido_id,
    nome, codigo_interno, unidade_medida,
    estoque_atual, estoque_minimo, ponto_reposicao,
    valor_custo, valor_venda
) VALUES

-- ANESTESICOS (categoria 4)
(4, 5, 'Lidocaina 2% c/ Epinefrina 1:100.000 - Cx 50un',    'ANE-001','CX',  8, 3, 5,  85.00, 0),
(4, 5, 'Mepivacaina 3% s/ Vasoconstritor - Cx 50un',        'ANE-002','CX',  5, 2, 4,  92.00, 0),
(4, 5, 'Articaina 4% c/ Epinefrina 1:100.000 - Cx 50un',   'ANE-003','CX',  4, 2, 3,  98.00, 0),
(4, 7, 'Agulha Gengival Curta 30G - Cx 100un',              'ANE-004','CX', 10, 4, 6,  28.00, 0),
(4, 7, 'Agulha Gengival Longa 27G - Cx 100un',              'ANE-005','CX',  8, 3, 5,  30.00, 0),

-- RESTAURADORES (categoria 1)
(1, 1, 'Resina Composta Filtek Z350 A1 - Seringa 4g',       'REST-001','UN', 12, 4, 6,  42.00, 0),
(1, 1, 'Resina Composta Filtek Z350 A2 - Seringa 4g',       'REST-002','UN', 18, 4, 6,  42.00, 0),
(1, 1, 'Resina Composta Filtek Z350 A3 - Seringa 4g',       'REST-003','UN', 10, 4, 6,  42.00, 0),
(1, 3, 'Adesivo Scotchbond Universal - Frasco 5ml',         'REST-004','UN',  6, 2, 4,  88.00, 0),
(1, 7, 'Ionomero de Vidro Riva Light Cure - Po+liquido',    'REST-005','KT',  4, 2, 3, 110.00, 0),
(1, 7, 'Amalgama DFL Dispersalloy 600mg - Cx 50un',         'REST-006','CX',  3, 1, 2,  95.00, 0),

-- ENDODONTICOS (categoria 2)
(2, 5, 'Lima K FlexFile 21mm Assortment - Cx 6un',          'ENDO-001','CX', 15, 5, 8,  22.00, 0),
(2, 5, 'Lima K FlexFile 25mm Assortment - Cx 6un',          'ENDO-002','CX', 12, 5, 8,  22.00, 0),
(2, 5, 'Cimento Endodontico AH Plus - Seringa 2x4g',        'ENDO-003','UN',  5, 2, 4, 165.00, 0),
(2, 7, 'Hipoclorito de Sodio 2,5% - Galao 5L',             'ENDO-004','GL',  4, 2, 3,  38.00, 0),
(2, 7, 'EDTA Biodinamica 17% - Frasco 100ml',               'ENDO-005','UN',  6, 2, 4,  25.00, 0),

-- PROFILAXIA (categoria 5)
(5, 7, 'Pasta Profilatica Detartrine 200g Laranja',         'PROF-001','UN', 10, 4, 6,  28.00, 150.00),
(5, 7, 'Pasta Profilatica Detartrine 200g Menta',           'PROF-002','UN',  8, 4, 6,  28.00, 150.00),
(5, 4, 'Escova Robinson para Micromotor - Cx 12un',         'PROF-003','CX',  5, 2, 4,  18.00, 0),
(5, 7, 'Verniz de Fluor Duofluorid - Frasco 10ml',          'PROF-004','UN',  4, 2, 3,  95.00, 60.00),
(5, 7, 'Gel de Fluor FGM 1,23% - Pote 200g',               'PROF-005','UN',  6, 2, 4,  25.00, 60.00),

-- EPI / DESCARTAVEIS (categoria 8)
(8, 7, 'Luva Procedimento Latex Tam. P - Cx 100un',         'EPI-001','CX', 20, 8,12,  28.00, 0),
(8, 7, 'Luva Procedimento Latex Tam. M - Cx 100un',         'EPI-002','CX', 25, 8,12,  28.00, 0),
(8, 7, 'Luva Procedimento Latex Tam. G - Cx 100un',         'EPI-003','CX', 15, 5, 8,  28.00, 0),
(8, 7, 'Mascara Cirurgica Tripla Camada - Cx 50un',         'EPI-004','CX', 20, 8,12,  22.00, 0),
(8, 7, 'Babador de TNT - Pacote 100un',                     'EPI-005','PC', 15, 5, 8,  32.00, 0),
(8, 7, 'Gorro Descartavel - Pacote 100un',                  'EPI-006','PC', 10, 4, 6,  18.00, 0),

-- IMPRESSAO (categoria 3)
(3, 1, 'Alginato Jeltrate Plus - Pote 454g',                'IMP-001','UN',  6, 2, 4,  55.00, 0),
(3, 5, 'Silicone de Condensacao Speedex - Kit 900ml',       'IMP-002','KT',  3, 1, 2, 220.00, 0),
(3, 7, 'Gesso Pedra Tipo IV - Saco 5kg',                    'IMP-003','SC',  4, 2, 3,  85.00, 0),

-- CLAREAMENTO (categoria 1)
(1, 6, 'Peroxido de Carbamida 16% FGM - Seringa 3g',        'CLAR-001','UN', 10, 3, 5,  45.00, 350.00),
(1, 6, 'Peroxido de Hidrogenio 35% FGM - Seringa 3g',       'CLAR-002','UN',  8, 3, 5,  55.00, 700.00),

-- DESCARTAVEIS GERAIS (categoria 8)
(8, 7, 'Sugador Cirurgico - Pacote 40un',                   'DESC-001','PC', 15, 5, 8,  25.00, 0),
(8, 7, 'Ponta Aspiradora de Saliva - Cx 100un',             'DESC-002','CX', 12, 4, 6,  22.00, 0),
(8, 7, 'Rolete de Algodao - Pacote 68un',                   'DESC-003','PC', 20, 8,12,  12.00, 0),
(8, 7, 'Fio Dental Johnson 25m',                             'DESC-004','UN', 50,15,25,   4.50, 0),

-- ESTERILIZACAO (categoria 12)
(12,7, 'Envelope para Autoclave 90x260mm - Rolo 200m',      'ESTER-001','RL',  5, 2, 3,  75.00, 0),
(12,7, 'Indicador Quimico para Autoclave - Tira 250un',     'ESTER-002','CX', 10, 4, 6,  35.00, 0),
(12,7, 'Glutaraldeido 2% - Frasco 1L',                      'ESTER-003','UN',  6, 2, 4,  65.00, 0);
