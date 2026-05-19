-- =============================================================================
--  01_schema.sql
--  Definição de todas as tabelas do sistema OdontoRecife
--
--  Esse é o arquivo mais importante do projeto. Aqui defino a estrutura
--  de tudo: tipos, tabelas, colunas, constraints. A ordem importa porque
--  algumas tabelas dependem de outras (chaves estrangeiras).
--
--  Dica de estudo: antes de criar qualquer tabela, desenhe o diagrama ER
--  no papel. Eu perdi algumas horas refazendo relações que poderiam ter
--  sido pensadas antes. Aprenda com meu erro!
--
--  Banco: PostgreSQL 13+
-- =============================================================================


-- =============================================================================
--  EXTENSÕES
--
--  O Postgres tem extensões que adicionam funcionalidades extras.
--  Preciso ativar três:
--    - uuid-ossp: gera UUIDs (não usei aqui, mas deixo disponível pra API)
--    - unaccent:  remove acentos em buscas de texto (ex: "jose" encontra "José")
--    - pg_trgm:   permite busca por similaridade de strings (tipo LIKE, mas melhor)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";


-- =============================================================================
--  TIPOS ENUMERADOS (ENUM)
--
--  ENUMs são ótimos pra campos com valores fixos e conhecidos. Em vez de
--  guardar a string "MASCULINO" ou "M" solta na tabela (sujeito a erro de
--  digitação), eu defino os valores aceitos de uma vez aqui.
--
--  Vantagem: o banco rejeita qualquer valor fora da lista. Isso é validação
--  de dados sem precisar de código na aplicação.
--
--  Desvantagem: adicionar um novo valor no ENUM depois que tem dados
--  é possível, mas exige um ALTER TYPE. Planeje bem antes de criar.
-- =============================================================================

CREATE TYPE sexo_enum            AS ENUM ('M', 'F', 'OUTRO');
CREATE TYPE estado_civil_enum    AS ENUM ('SOLTEIRO','CASADO','DIVORCIADO','VIUVO','UNIAO_ESTAVEL','OUTRO');

-- Tipo de telefone — guardei WHATSAPP separado porque tem impacto no envio
-- de notificações automáticas (lembretes de consulta, cobranças, etc.)
CREATE TYPE tipo_telefone_enum   AS ENUM ('CELULAR','RESIDENCIAL','COMERCIAL','WHATSAPP');

-- Status da consulta — esse fluxo foi o que mais deu trabalho de pensar.
-- Uma consulta começa como AGENDADA, vai pra CONFIRMADA quando o paciente
-- confirma, EM_ATENDIMENTO quando o dentista chama, e aí CONCLUIDA ou FALTOU.
CREATE TYPE status_consulta_enum AS ENUM ('AGENDADA','CONFIRMADA','EM_ATENDIMENTO','CONCLUIDA','CANCELADA','FALTOU','REMARCADA');

CREATE TYPE tipo_pagamento_enum  AS ENUM ('DINHEIRO','CARTAO_DEBITO','CARTAO_CREDITO','PIX','BOLETO','TRANSFERENCIA','CONVENIO','CHEQUE');
CREATE TYPE status_pagamento_enum AS ENUM ('PENDENTE','PARCIAL','PAGO','ATRASADO','CANCELADO','ESTORNADO');
CREATE TYPE status_plano_enum    AS ENUM ('ATIVO','CONCLUIDO','CANCELADO','SUSPENSO','ORCAMENTO');

-- Notação FDI: cada dente tem faces. Nem todos os dentes têm todas as faces
-- (ex: dentes anteriores têm INCISAL, não OCLUSAL). Mas guardei todas pra
-- flexibilidade — a aplicação controla quais aparecem na interface.
CREATE TYPE face_dente_enum      AS ENUM ('VESTIBULAR','LINGUAL','MESIAL','DISTAL','OCLUSAL','INCISAL','CERVICAL','RAIZ');
CREATE TYPE status_dente_enum    AS ENUM ('HÍGIDO','CARIADO','RESTAURADO','EXTRAÍDO','AUSENTE','IMPLANTE','COROA','ENDODONTIA','FRATURADO','MANCHADO');

CREATE TYPE tipo_movimento_estoque_enum AS ENUM ('ENTRADA','SAIDA','AJUSTE','DEVOLUCAO','VENCIMENTO');
CREATE TYPE prioridade_enum      AS ENUM ('BAIXA','MEDIA','ALTA','URGENTE');
CREATE TYPE turno_enum           AS ENUM ('MANHA','TARDE','NOITE','INTEGRAL');


-- =============================================================================
--  MÓDULO: CLÍNICA
--
--  Comecei pelo "centro" do sistema — a própria clínica. Tudo se relaciona
--  com ela (pacientes, funcionários, financeiro...).
--
--  Deixei o design pensando em multi-clínica desde o início, mesmo que a
--  clínica tenha só uma unidade hoje. Escalar depois é muito mais fácil
--  do que refatorar o banco inteiro mais tarde.
-- =============================================================================

CREATE TABLE clinica (
    id              SERIAL PRIMARY KEY,
    razao_social    VARCHAR(200) NOT NULL,
    nome_fantasia   VARCHAR(200),
    cnpj            CHAR(18) UNIQUE NOT NULL,

    -- CRO-PJ: toda clínica precisa ter registro no Conselho Regional de Odontologia
    cro_pj          VARCHAR(20),

    email           VARCHAR(150),
    site            VARCHAR(150),
    logo_url        TEXT,

    -- Endereço completo — separei em campos pra facilitar filtros por bairro/cidade
    logradouro      VARCHAR(200),
    numero          VARCHAR(10),
    complemento     VARCHAR(100),
    bairro          VARCHAR(100),
    cidade          VARCHAR(100) DEFAULT 'Recife',
    estado          CHAR(2)      DEFAULT 'PE',
    cep             CHAR(9),

    telefone_principal  VARCHAR(20),
    telefone_secundario VARCHAR(20),
    whatsapp            VARCHAR(20),

    -- Configurações de agenda: define os horários padrão da clínica
    -- O intervalo_consulta é o "bloco mínimo" de tempo pra agendar (em minutos)
    horario_abertura    TIME DEFAULT '08:00',
    horario_fechamento  TIME DEFAULT '18:00',
    intervalo_consulta  INT  DEFAULT 30,

    ativo         BOOLEAN     DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Salas de atendimento / consultórios
-- Importante porque duas consultas não podem acontecer na mesma sala ao mesmo tempo
CREATE TABLE salas (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    nome        VARCHAR(50) NOT NULL,
    descricao   TEXT,
    capacidade  INT     DEFAULT 1,
    ativa       BOOLEAN DEFAULT TRUE,
    criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- Controle de equipamentos — útil pra saber quando precisa de manutenção
-- Uma cadeira odontológica sem manutenção pode travar no meio de uma cirurgia!
CREATE TABLE equipamentos (
    id                      SERIAL PRIMARY KEY,
    sala_id                 INT REFERENCES salas(id),
    nome                    VARCHAR(100) NOT NULL,
    marca                   VARCHAR(100),
    modelo                  VARCHAR(100),
    numero_serie            VARCHAR(100),
    data_aquisicao          DATE,
    data_ultima_manutencao  DATE,
    proxima_manutencao      DATE,
    valor_aquisicao         NUMERIC(12,2),
    ativo                   BOOLEAN DEFAULT TRUE,
    observacoes             TEXT,
    criado_em               TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: ESPECIALIDADES E PROCEDIMENTOS
--
--  Esse módulo é o "catálogo" da clínica. Separei especialidades de
--  procedimentos porque um procedimento pertence a uma especialidade,
--  e os dentistas têm especialidades (e consequentemente podem realizar
--  determinados procedimentos).
--
--  Os códigos TUSS e CBHPM são tabelas padronizadas pela ANS e AMB
--  respectivamente. Convênios usam esses códigos pra processar cobranças.
-- =============================================================================

CREATE TABLE especialidades (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativa     BOOLEAN DEFAULT TRUE
);

CREATE TABLE procedimentos (
    id               SERIAL PRIMARY KEY,
    especialidade_id INT REFERENCES especialidades(id),

    -- Códigos das tabelas de saúde — essenciais pra trabalhar com convênios
    codigo_tuss  VARCHAR(20), -- Terminologia Unificada da Saúde Suplementar
    codigo_cbhpm VARCHAR(20), -- Classificação Brasileira Hierarquizada de Procedimentos Médicos

    nome              VARCHAR(200)   NOT NULL,
    descricao         TEXT,
    duracao_minutos   INT            DEFAULT 30,
    valor_base        NUMERIC(12,2)  NOT NULL DEFAULT 0,
    valor_minimo      NUMERIC(12,2), -- pra clínicas que negociam faixas de preço
    valor_maximo      NUMERIC(12,2),

    -- Flags importantes pra logística do atendimento
    requer_rx        BOOLEAN DEFAULT FALSE, -- precisa de radiografia prévia?
    requer_anestesia BOOLEAN DEFAULT FALSE,

    ativo         BOOLEAN     DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: PACIENTES
--
--  Tabela central do sistema. Tentei equilibrar entre ter dados suficientes
--  pra uso clínico/financeiro e não virar um formulário interminável.
--
--  Separei telefones em tabela própria (paciente_telefones) porque um
--  paciente pode ter vários números, e precisamos saber qual é o principal
--  e se tem WhatsApp pra notificações automáticas.
-- =============================================================================

CREATE TABLE pacientes (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),

    -- Dados pessoais
    nome_completo   VARCHAR(200) NOT NULL,
    cpf             CHAR(14) UNIQUE,        -- formato 000.000.000-00
    rg              VARCHAR(20),
    data_nascimento DATE,
    sexo            sexo_enum,
    estado_civil    estado_civil_enum,
    profissao       VARCHAR(100),
    nacionalidade   VARCHAR(80) DEFAULT 'Brasileiro(a)',

    -- Endereço
    logradouro  VARCHAR(200),
    numero      VARCHAR(10),
    complemento VARCHAR(100),
    bairro      VARCHAR(100),
    cidade      VARCHAR(100) DEFAULT 'Recife',
    estado      CHAR(2)      DEFAULT 'PE',
    cep         CHAR(9),

    email VARCHAR(150),

    -- Convênio — FK definida depois (convenios ainda não existe nesse ponto)
    -- Isso é uma das situações onde a ordem de criação das tabelas importa.
    -- Resolvi com ALTER TABLE lá embaixo, depois de criar convenios.
    convenio_id          INT,
    numero_carteirinha   VARCHAR(50),
    validade_carteirinha DATE,

    -- Responsável: necessário pra pacientes menores de idade
    responsavel_nome       VARCHAR(200),
    responsavel_cpf        CHAR(14),
    responsavel_parentesco VARCHAR(50),

    -- Dados de marketing — saber como o paciente chegou até a clínica
    -- ajuda a entender quais canais funcionam melhor
    como_conheceu VARCHAR(100),
    observacoes   TEXT,
    foto_url      TEXT,

    ativo                BOOLEAN DEFAULT TRUE,
    primeiro_atendimento DATE,    -- preenchido automaticamente pelo trigger
    criado_em            TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em        TIMESTAMPTZ DEFAULT NOW()
);

-- Separei os telefones em tabela própria pra suportar múltiplos contatos
-- sem precisar de colunas como telefone1, telefone2, telefone3 (péssima prática!)
CREATE TABLE paciente_telefones (
    id          SERIAL PRIMARY KEY,
    paciente_id INT NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    tipo        tipo_telefone_enum DEFAULT 'CELULAR',
    numero      VARCHAR(20) NOT NULL,
    principal   BOOLEAN     DEFAULT FALSE, -- qual número ligar primeiro?
    observacao  VARCHAR(100)
);

-- Alergias em tabela separada pelo mesmo motivo — um paciente pode ter várias,
-- e é um dado crítico: aplicar anestesia num paciente alérgico pode ser fatal.
CREATE TABLE paciente_alergias (
    id          SERIAL PRIMARY KEY,
    paciente_id INT NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    substancia  VARCHAR(200) NOT NULL,
    reacao      TEXT,
    gravidade   VARCHAR(50),   -- leve, moderada, grave, anafilaxia
    confirmado  BOOLEAN        DEFAULT FALSE, -- confirmado por médico/teste?
    registrado_em TIMESTAMPTZ  DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: FUNCIONÁRIOS E DENTISTAS
--
--  Aqui tomei uma decisão importante: separar funcionários de dentistas.
--  O motivo é que nem todo dentista é funcionário da clínica — alguns são
--  autônomos que apenas alugam o espaço. E funcionários não-dentistas
--  (recepcionistas, auxiliares) também precisam estar no sistema.
--
--  Então: todo dentista PODE ter um funcionario_id, mas não é obrigatório.
-- =============================================================================

CREATE TABLE cargos (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativo     BOOLEAN DEFAULT TRUE
);

CREATE TABLE funcionarios (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    cargo_id    INT REFERENCES cargos(id),

    nome_completo   VARCHAR(200) NOT NULL,
    cpf             CHAR(14) UNIQUE NOT NULL,
    rg              VARCHAR(20),
    data_nascimento DATE,
    sexo            sexo_enum,
    email           VARCHAR(150),
    telefone        VARCHAR(20),

    logradouro  VARCHAR(200),
    numero      VARCHAR(10),
    complemento VARCHAR(100),
    bairro      VARCHAR(100),
    cidade      VARCHAR(100) DEFAULT 'Recife',
    estado      CHAR(2)      DEFAULT 'PE',
    cep         CHAR(9),

    data_admissao DATE NOT NULL,
    data_demissao DATE,          -- NULL = ainda trabalhando
    salario       NUMERIC(12,2),
    turno         turno_enum DEFAULT 'INTEGRAL',

    -- Login no sistema — importante pra auditoria de quem fez o quê
    usuario_sistema VARCHAR(50) UNIQUE,

    ativo         BOOLEAN     DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dentistas (
    id             SERIAL PRIMARY KEY,
    funcionario_id INT UNIQUE REFERENCES funcionarios(id), -- nullable: dentista autônomo

    -- CRO é o registro profissional obrigatório — sem isso não pode atender
    cro_numero VARCHAR(20) NOT NULL,
    cro_estado CHAR(2)     DEFAULT 'PE',

    -- Campos extras pra dentistas autônomos (sem vínculo em funcionarios)
    nome_completo VARCHAR(200),
    cpf           CHAR(14),
    email         VARCHAR(150),
    telefone      VARCHAR(20),

    -- Comissão sobre os procedimentos realizados
    -- Ex: 30% significa que o dentista recebe 30% do valor cobrado ao paciente
    comissao_percentual NUMERIC(5,2) DEFAULT 0,

    -- Cor pra exibir na agenda visual (formato HEX)
    cor_agenda CHAR(7) DEFAULT '#3B82F6',

    ativo     BOOLEAN     DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Dentista pode ter múltiplas especialidades (ex: clínico geral + endodontista)
-- A flag "principal" indica a especialidade principal pra exibição
CREATE TABLE dentista_especialidades (
    dentista_id      INT NOT NULL REFERENCES dentistas(id) ON DELETE CASCADE,
    especialidade_id INT NOT NULL REFERENCES especialidades(id),
    principal        BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (dentista_id, especialidade_id)
);

-- Grade de disponibilidade semanal de cada dentista
-- dia_semana: 0 = Domingo, 1 = Segunda, ..., 6 = Sábado
CREATE TABLE dentista_disponibilidade (
    id          SERIAL PRIMARY KEY,
    dentista_id INT NOT NULL REFERENCES dentistas(id) ON DELETE CASCADE,
    dia_semana  SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL,
    hora_fim    TIME NOT NULL,
    sala_id     INT REFERENCES salas(id), -- qual sala usa nesse turno
    ativo       BOOLEAN DEFAULT TRUE
);


-- =============================================================================
--  MÓDULO: CONVÊNIOS / PLANOS DE SAÚDE
--
--  Trabalhar com convênios odontológicos é complexo: cada plano tem sua
--  tabela de valores, carência, e limite de procedimentos por ano.
--  Modelei pra suportar tudo isso sem gambiarras.
-- =============================================================================

CREATE TABLE convenios (
    id           SERIAL PRIMARY KEY,
    nome         VARCHAR(150) NOT NULL,
    razao_social VARCHAR(200),
    cnpj         CHAR(18),
    ans_registro VARCHAR(20), -- número de registro na ANS (Agência Nacional de Saúde)
    email        VARCHAR(150),
    telefone     VARCHAR(20),
    site         VARCHAR(150),
    observacoes  TEXT,
    ativo        BOOLEAN     DEFAULT TRUE,
    criado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- Valores que cada convênio paga por procedimento
-- Isso é diferente do valor_base da tabela procedimentos (que é o valor particular)
CREATE TABLE convenio_procedimentos (
    id              SERIAL PRIMARY KEY,
    convenio_id     INT NOT NULL REFERENCES convenios(id),
    procedimento_id INT NOT NULL REFERENCES procedimentos(id),
    codigo_convenio VARCHAR(30),           -- código interno do convênio (diferente do TUSS às vezes)
    valor_convenio  NUMERIC(12,2) NOT NULL,
    carencia_dias   INT DEFAULT 0,         -- quantos dias o paciente precisa esperar pra usar
    limite_anual    INT,                   -- quantidade máxima por ano (NULL = sem limite)
    vigencia_inicio DATE,
    vigencia_fim    DATE,
    UNIQUE(convenio_id, procedimento_id)
);

-- Aqui está a FK que não pude criar antes (convenios não existia quando criei pacientes)
-- ALTER TABLE permite adicionar constraints depois — útil pra dependências circulares
ALTER TABLE pacientes ADD CONSTRAINT fk_paciente_convenio
    FOREIGN KEY (convenio_id) REFERENCES convenios(id);


-- =============================================================================
--  MÓDULO: AGENDAMENTO
--
--  A agenda é o coração operacional da clínica. Toda consulta tem:
--    - Um paciente
--    - Um dentista
--    - Uma sala
--    - Um horário
--    - Um status que evolui ao longo do dia
--
--  O principal desafio aqui foi evitar conflitos de horário. Resolvi isso
--  com um trigger que valida antes de qualquer INSERT ou UPDATE.
-- =============================================================================

CREATE TABLE consultas (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    paciente_id INT NOT NULL REFERENCES pacientes(id),
    dentista_id INT NOT NULL REFERENCES dentistas(id),
    sala_id     INT REFERENCES salas(id),
    procedimento_id INT REFERENCES procedimentos(id),

    -- Horário — uso TIMESTAMPTZ (com fuso) pra evitar problemas de timezone
    data_hora_inicio TIMESTAMPTZ NOT NULL,
    data_hora_fim    TIMESTAMPTZ,
    duracao_minutos  INT DEFAULT 30,

    status     status_consulta_enum DEFAULT 'AGENDADA',
    prioridade prioridade_enum      DEFAULT 'MEDIA',

    -- Financeiro básico — detalhes ficam na tabela pagamentos
    valor_cobrado NUMERIC(12,2),
    convenio_id   INT REFERENCES convenios(id),

    -- Rastreabilidade: quem agendou e quando cada etapa aconteceu
    agendado_por INT REFERENCES funcionarios(id),
    confirmado_em TIMESTAMPTZ, -- quando o paciente confirmou (SMS, WhatsApp, ligação)
    chegou_em     TIMESTAMPTZ, -- quando o paciente chegou na clínica
    iniciou_em    TIMESTAMPTZ, -- quando o dentista começou o atendimento
    concluiu_em   TIMESTAMPTZ, -- quando terminou

    motivo_cancelamento TEXT,
    observacoes         TEXT,
    criado_em           TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em       TIMESTAMPTZ DEFAULT NOW()
);

-- Bloqueios de agenda: férias, reuniões, manutenção de equipamento...
-- Impede que o sistema agende consultas nesses períodos
CREATE TABLE agenda_bloqueio (
    id               SERIAL PRIMARY KEY,
    dentista_id      INT REFERENCES dentistas(id), -- NULL = bloqueia toda a clínica
    sala_id          INT REFERENCES salas(id),
    data_hora_inicio TIMESTAMPTZ NOT NULL,
    data_hora_fim    TIMESTAMPTZ NOT NULL,
    motivo           VARCHAR(200),
    recorrente       BOOLEAN DEFAULT FALSE, -- feriado semanal, intervalo de almoço, etc.
    criado_por       INT REFERENCES funcionarios(id),
    criado_em        TIMESTAMPTZ DEFAULT NOW()
);

-- Fila de espera: paciente quer consultar mas não tem horário disponível
CREATE TABLE lista_espera (
    id              SERIAL PRIMARY KEY,
    clinica_id      INT NOT NULL REFERENCES clinica(id),
    paciente_id     INT NOT NULL REFERENCES pacientes(id),
    dentista_id     INT REFERENCES dentistas(id),
    procedimento_id INT REFERENCES procedimentos(id),
    data_preferencia  DATE,
    turno_preferencia turno_enum,
    prioridade        prioridade_enum DEFAULT 'MEDIA',
    observacoes       TEXT,
    atendido          BOOLEAN     DEFAULT FALSE, -- foi para uma consulta?
    criado_em         TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: PRONTUÁRIO ELETRÔNICO
--
--  O prontuário é o registro clínico do paciente. Por lei (CFO), deve ser
--  mantido por no mínimo 20 anos. Então: nunca deleto dados de prontuário,
--  apenas marco como arquivado se necessário.
--
--  Estrutura:
--    prontuarios → anamnese (histórico de saúde)
--    prontuarios → odontograma (mapa dos dentes)
--    prontuarios → evolucoes (o que foi feito em cada consulta)
-- =============================================================================

CREATE TABLE prontuarios (
    id                      SERIAL PRIMARY KEY,
    paciente_id             INT NOT NULL UNIQUE REFERENCES pacientes(id), -- 1 prontuário por paciente
    numero                  VARCHAR(20) UNIQUE NOT NULL, -- gerado automaticamente (ex: 2025-00042)
    data_abertura           DATE DEFAULT CURRENT_DATE,
    dentista_responsavel_id INT REFERENCES dentistas(id),
    observacoes_gerais      TEXT,
    criado_em               TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em           TIMESTAMPTZ DEFAULT NOW()
);

-- Anamnese: ficha de saúde geral do paciente
-- Mantive os campos booleanos pra triagem rápida (hipertensão, diabetes...)
-- mas há um campo de texto livre pra detalhes. É um balanço entre estrutura e flexibilidade.
CREATE TABLE anamnese (
    id             SERIAL PRIMARY KEY,
    prontuario_id  INT NOT NULL REFERENCES prontuarios(id),
    data_preenchimento DATE DEFAULT CURRENT_DATE,
    dentista_id        INT REFERENCES dentistas(id),

    queixa_principal       TEXT,
    historia_doenca_atual  TEXT,

    -- Sinais vitais — importante pra saber se pode anestesiar com segurança
    pressao_arterial    VARCHAR(20), -- ex: "120/80"
    frequencia_cardiaca INT,
    peso_kg             NUMERIC(6,2),
    altura_cm           NUMERIC(5,2),

    -- Doenças sistêmicas que impactam o tratamento odontológico
    hipertensao  BOOLEAN DEFAULT FALSE,
    diabetes     BOOLEAN DEFAULT FALSE, -- impacta cicatrização
    cardiopatia  BOOLEAN DEFAULT FALSE, -- pode contraindicar vasoconstritores
    asma         BOOLEAN DEFAULT FALSE,
    epilepsia    BOOLEAN DEFAULT FALSE,
    hiv          BOOLEAN DEFAULT FALSE,
    hepatite     BOOLEAN DEFAULT FALSE,
    doenca_renal BOOLEAN DEFAULT FALSE,
    coagulopatia BOOLEAN DEFAULT FALSE, -- problema de coagulação — risco em cirurgias
    osteoporose  BOOLEAN DEFAULT FALSE, -- uso de bisfosfonatos pode complicar implantes
    gestante     BOOLEAN DEFAULT FALSE,
    semanas_gestacao INT,

    usa_medicamentos  BOOLEAN DEFAULT FALSE,
    medicamentos_desc TEXT,    -- quais medicamentos usa? importante pra interações

    -- Hábitos que afetam saúde bucal
    fuma          BOOLEAN DEFAULT FALSE,
    consome_alcool BOOLEAN DEFAULT FALSE,
    bruxismo      BOOLEAN DEFAULT FALSE, -- ranger de dentes — desgasta próteses e restaurações

    ultima_consulta_odonto DATE,
    medo_dentista          BOOLEAN DEFAULT FALSE, -- ajuda o dentista a adaptar a abordagem
    tratamentos_anteriores TEXT,

    observacoes        TEXT,
    assinatura_paciente BOOLEAN DEFAULT FALSE, -- paciente assinou o formulário físico?
    criado_em          TIMESTAMPTZ DEFAULT NOW()
);

-- Odontograma usando notação FDI (Fédération Dentaire Internationale)
-- Cada dente tem um número de 2 dígitos: primeiro indica o quadrante (1-4),
-- segundo indica a posição (1-8). Ex: 36 = quadrante 3, dente 6 = molar inferior esquerdo
CREATE TABLE odontograma (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT     NOT NULL REFERENCES prontuarios(id),
    numero_dente  SMALLINT NOT NULL CHECK (numero_dente BETWEEN 11 AND 88),
    status        status_dente_enum DEFAULT 'HÍGIDO',
    observacao    TEXT,
    atualizado_em TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(prontuario_id, numero_dente)  -- um registro por dente por prontuário
);

-- Estado de cada face do dente — granularidade clínica total
-- Uma restauração pode estar na face mesial mas não na distal do mesmo dente
CREATE TABLE odontograma_faces (
    id             SERIAL PRIMARY KEY,
    odontograma_id INT NOT NULL REFERENCES odontograma(id) ON DELETE CASCADE,
    face           face_dente_enum NOT NULL,
    status         status_dente_enum DEFAULT 'HÍGIDO',
    procedimento_id INT REFERENCES procedimentos(id), -- qual procedimento gerou esse estado?
    cor_material   VARCHAR(50),   -- ex: "Compósito A2", "Amálgama" — útil pra restaurações
    observacao     TEXT,
    data_registro  DATE DEFAULT CURRENT_DATE,
    UNIQUE(odontograma_id, face)
);

-- Evolução clínica: o "diário" do que aconteceu em cada consulta
-- É o registro mais importante do prontuário — documenta todo o tratamento realizado
CREATE TABLE evolucoes (
    id              SERIAL PRIMARY KEY,
    prontuario_id   INT NOT NULL REFERENCES prontuarios(id),
    consulta_id     INT REFERENCES consultas(id),
    dentista_id     INT NOT NULL REFERENCES dentistas(id),
    data_evolucao   TIMESTAMPTZ DEFAULT NOW(),
    descricao       TEXT NOT NULL,              -- o que foi observado/feito
    procedimentos_realizados TEXT,
    dentes_tratados VARCHAR(200),               -- ex: "16, 17, 26" — lista informal
    proximos_passos TEXT,                       -- planejamento pra próxima sessão
    criado_em       TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: PLANOS DE TRATAMENTO E ORÇAMENTOS
--
--  Quando o paciente precisa de vários procedimentos, cria-se um plano.
--  O plano agrupa os procedimentos, define a ordem de execução e o valor total.
--  O orçamento é a proposta formal que o paciente assina.
--
--  Fluxo típico:
--    1. Dentista avalia o paciente
--    2. Cria um plano de tratamento com os procedimentos necessários
--    3. Gera um orçamento (proposta com preços)
--    4. Paciente aprova → plano muda para ATIVO
--    5. Procedimentos são executados consulta por consulta
-- =============================================================================

CREATE TABLE planos_tratamento (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    dentista_id   INT NOT NULL REFERENCES dentistas(id),
    titulo        VARCHAR(200),
    status        status_plano_enum DEFAULT 'ORCAMENTO',
    data_inicio           DATE,
    data_previsao_fim     DATE,
    data_conclusao        DATE,

    -- Valores calculados automaticamente pelo trigger quando itens são alterados
    valor_total         NUMERIC(12,2) DEFAULT 0,
    desconto_percentual NUMERIC(5,2)  DEFAULT 0,
    desconto_valor      NUMERIC(12,2) DEFAULT 0,
    valor_final         NUMERIC(12,2) DEFAULT 0,

    observacoes  TEXT,
    aprovado_em  TIMESTAMPTZ,
    criado_em    TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE itens_plano (
    id              SERIAL PRIMARY KEY,
    plano_id        INT NOT NULL REFERENCES planos_tratamento(id) ON DELETE CASCADE,
    procedimento_id INT NOT NULL REFERENCES procedimentos(id),
    numero_dente    SMALLINT,         -- qual dente será tratado (pode ser nulo pra procedimentos gerais)
    face_dente      face_dente_enum,  -- qual face (ex: só restaurar a face mesial)
    quantidade      INT           DEFAULT 1,
    valor_unitario  NUMERIC(12,2) NOT NULL,

    -- GENERATED ALWAYS AS: o banco calcula e garante essa coluna automaticamente.
    -- Nunca vai ter inconsistência entre valor_unitario e valor_total.
    valor_total  NUMERIC(12,2) GENERATED ALWAYS AS (quantidade * valor_unitario) STORED,

    ordem_execucao INT     DEFAULT 1,  -- em que ordem realizar os procedimentos
    status         VARCHAR(30) DEFAULT 'PENDENTE',
    consulta_id    INT REFERENCES consultas(id), -- em qual consulta foi realizado
    concluido_em   TIMESTAMPTZ,
    observacoes    TEXT
);


-- =============================================================================
--  MÓDULO: FINANCEIRO
--
--  Separei em três níveis:
--    - orcamentos: a proposta (pode não virar pagamento)
--    - pagamentos: o registro principal de uma cobrança
--    - parcelas: o parcelamento de um pagamento
--
--  Esse design permite controlar inadimplência por parcela individual,
--  e também fazer conciliação financeira mensal de forma precisa.
-- =============================================================================

CREATE TABLE orcamentos (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    paciente_id INT NOT NULL REFERENCES pacientes(id),
    dentista_id INT REFERENCES dentistas(id),
    plano_id    INT REFERENCES planos_tratamento(id),
    numero      VARCHAR(20) UNIQUE NOT NULL, -- gerado pela função fn_gerar_numero_orcamento()
    data_emissao  DATE DEFAULT CURRENT_DATE,
    validade_dias INT  DEFAULT 30,   -- orçamentos costumam vencer em 30 dias
    valor_bruto   NUMERIC(12,2) DEFAULT 0,
    desconto_valor NUMERIC(12,2) DEFAULT 0,
    valor_liquido  NUMERIC(12,2) DEFAULT 0,
    status         VARCHAR(20)   DEFAULT 'PENDENTE', -- PENDENTE/APROVADO/RECUSADO/EXPIRADO
    observacoes    TEXT,
    aprovado_em    TIMESTAMPTZ,
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

-- Pagamento: a cobrança em si. Pode ser vinculada a uma consulta específica
-- ou a um plano de tratamento inteiro.
CREATE TABLE pagamentos (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    paciente_id INT NOT NULL REFERENCES pacientes(id),
    consulta_id INT REFERENCES consultas(id),
    plano_id    INT REFERENCES planos_tratamento(id),
    orcamento_id INT REFERENCES orcamentos(id),

    -- número_recibo é gerado automaticamente pelo trigger trg_numero_recibo
    numero_recibo VARCHAR(30) UNIQUE,

    descricao     TEXT,
    valor_total   NUMERIC(12,2) NOT NULL,
    valor_desconto NUMERIC(12,2) DEFAULT 0,
    valor_pago    NUMERIC(12,2) DEFAULT 0,
    status        status_pagamento_enum DEFAULT 'PENDENTE',

    forma_pagamento tipo_pagamento_enum,
    numero_parcelas INT  DEFAULT 1,
    data_vencimento DATE,
    data_pagamento  DATE,

    -- Dados do convênio — quando parte ou tudo é pago pelo plano de saúde
    convenio_id   INT REFERENCES convenios(id),
    valor_convenio NUMERIC(12,2) DEFAULT 0,
    numero_guia    VARCHAR(50),  -- número da guia de autorização do convênio

    registrado_por INT REFERENCES funcionarios(id),
    observacoes    TEXT,
    criado_em      TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em  TIMESTAMPTZ DEFAULT NOW()
);

-- Parcelas — cada linha é uma prestação do pagamento
-- Esse detalhamento permite saber exatamente qual parcela está atrasada
CREATE TABLE parcelas (
    id              SERIAL PRIMARY KEY,
    pagamento_id    INT NOT NULL REFERENCES pagamentos(id) ON DELETE CASCADE,
    numero_parcela  INT NOT NULL,
    valor           NUMERIC(12,2) NOT NULL,
    data_vencimento DATE NOT NULL,
    data_pagamento  DATE,
    forma_pagamento tipo_pagamento_enum,
    status          status_pagamento_enum DEFAULT 'PENDENTE',
    codigo_transacao VARCHAR(100), -- NSU do cartão, ID do Pix, etc.
    observacoes     TEXT
);

-- Comissões dos dentistas — calculadas automaticamente quando um pagamento
-- é confirmado (via trigger). Guardadas pra facilitar o fechamento mensal.
CREATE TABLE comissoes (
    id          SERIAL PRIMARY KEY,
    dentista_id INT NOT NULL REFERENCES dentistas(id),
    pagamento_id INT NOT NULL REFERENCES pagamentos(id),
    consulta_id  INT REFERENCES consultas(id),
    valor_base          NUMERIC(12,2) NOT NULL,
    percentual          NUMERIC(5,2)  NOT NULL,
    valor_comissao      NUMERIC(12,2) NOT NULL,
    competencia         DATE NOT NULL, -- mês/ano de referência (sempre dia 1)
    pago                BOOLEAN DEFAULT FALSE,
    data_pagamento      DATE,
    criado_em           TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: ESTOQUE / MATERIAIS
--
--  Controle de insumos é crítico numa clínica odontológica. Falta de anestesia
--  ou luva no meio do dia paralisa o atendimento.
--
--  Implementei controle por lote pra:
--    1. Rastrear validade dos materiais (ANVISA exige isso pra alguns)
--    2. Controlar custos por lote de compra (cada lote pode ter um preço diferente)
--    3. Rastrear devolução ou descarte de material vencido
-- =============================================================================

CREATE TABLE categorias_material (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativa     BOOLEAN DEFAULT TRUE
);

CREATE TABLE fornecedores (
    id              SERIAL PRIMARY KEY,
    razao_social    VARCHAR(200) NOT NULL,
    nome_fantasia   VARCHAR(200),
    cnpj            CHAR(18) UNIQUE,
    inscricao_estadual VARCHAR(30),
    email           VARCHAR(150),
    telefone        VARCHAR(20),
    whatsapp        VARCHAR(20),
    site            VARCHAR(150),

    logradouro  VARCHAR(200),
    numero      VARCHAR(10),
    complemento VARCHAR(100),
    bairro      VARCHAR(100),
    cidade      VARCHAR(100),
    estado      CHAR(2),
    cep         CHAR(9),

    contato_nome       VARCHAR(150), -- nome do vendedor/representante
    contato_email      VARCHAR(150),
    prazo_entrega_dias INT,
    condicao_pagamento VARCHAR(100), -- ex: "30/60 dias", "à vista com 5% desconto"

    ativo       BOOLEAN     DEFAULT TRUE,
    observacoes TEXT,
    criado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE materiais (
    id                  SERIAL PRIMARY KEY,
    categoria_id        INT REFERENCES categorias_material(id),
    fornecedor_preferido_id INT REFERENCES fornecedores(id),
    nome                VARCHAR(200) NOT NULL,
    descricao           TEXT,
    codigo_interno      VARCHAR(50) UNIQUE,   -- código pra busca rápida no sistema
    codigo_fabricante   VARCHAR(50),

    unidade_medida VARCHAR(20) NOT NULL DEFAULT 'UN', -- UN, CX, KG, ML, L, etc.

    -- Controle de estoque
    estoque_atual   NUMERIC(12,3) DEFAULT 0,
    estoque_minimo  NUMERIC(12,3) DEFAULT 0,  -- abaixo disso, o sistema alerta
    estoque_maximo  NUMERIC(12,3),
    ponto_reposicao NUMERIC(12,3),  -- quantidade que dispara pedido de compra

    valor_custo NUMERIC(12,2),
    valor_venda NUMERIC(12,2), -- alguns materiais são cobrados do paciente (ex: moldeiras)

    -- Flags regulatórias
    requer_controle_lote BOOLEAN DEFAULT FALSE, -- precisa rastrear por lote?
    controlado_anvisa    BOOLEAN DEFAULT FALSE, -- material regulamentado pela ANVISA?

    ativo         BOOLEAN     DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Lotes de compra — cada entrada de estoque pode vir de um lote diferente
-- com validade e custo diferentes. Essencial pra FIFO (primeiro a vencer, primeiro a usar)
CREATE TABLE lotes_material (
    id                 SERIAL PRIMARY KEY,
    material_id        INT NOT NULL REFERENCES materiais(id),
    fornecedor_id      INT REFERENCES fornecedores(id),
    numero_lote        VARCHAR(50),
    numero_nota_fiscal VARCHAR(30),
    quantidade_entrada NUMERIC(12,3) NOT NULL,
    quantidade_atual   NUMERIC(12,3) NOT NULL, -- decrementado a cada saída
    data_fabricacao    DATE,
    data_validade      DATE,  -- CRÍTICO — material vencido não pode ser usado
    valor_unitario     NUMERIC(12,4),
    criado_em          TIMESTAMPTZ DEFAULT NOW()
);

-- Movimentos de estoque: toda entrada e saída fica registrada aqui
-- Isso garante rastreabilidade completa e permite reconstruir o histórico
CREATE TABLE movimentos_estoque (
    id          SERIAL PRIMARY KEY,
    material_id INT NOT NULL REFERENCES materiais(id),
    lote_id     INT REFERENCES lotes_material(id),
    tipo        tipo_movimento_estoque_enum NOT NULL,
    quantidade  NUMERIC(12,3) NOT NULL, -- positivo = entrada, negativo = saída
    valor_unitario NUMERIC(12,4),
    valor_total    NUMERIC(12,2),
    consulta_id    INT REFERENCES consultas(id), -- material usado em qual consulta?
    pedido_id      INT,  -- FK adicionada depois da criação de pedidos_compra
    motivo         TEXT,
    registrado_por INT REFERENCES funcionarios(id),
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

-- Pedidos de compra: quando o estoque chega no ponto de reposição,
-- cria-se um pedido. Depois que é recebido, gera movimentos de entrada.
CREATE TABLE pedidos_compra (
    id           SERIAL PRIMARY KEY,
    clinica_id   INT NOT NULL REFERENCES clinica(id),
    fornecedor_id INT NOT NULL REFERENCES fornecedores(id),
    numero_pedido VARCHAR(30) UNIQUE NOT NULL,
    data_pedido           DATE DEFAULT CURRENT_DATE,
    data_previsao_entrega DATE,
    data_entrega          DATE,
    status      VARCHAR(30) DEFAULT 'PENDENTE', -- PENDENTE/ENVIADO/RECEBIDO/CANCELADO
    valor_total NUMERIC(12,2) DEFAULT 0,
    observacoes TEXT,
    criado_por  INT REFERENCES funcionarios(id),
    criado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE itens_pedido (
    id          SERIAL PRIMARY KEY,
    pedido_id   INT NOT NULL REFERENCES pedidos_compra(id) ON DELETE CASCADE,
    material_id INT NOT NULL REFERENCES materiais(id),
    quantidade          NUMERIC(12,3) NOT NULL,
    valor_unitario      NUMERIC(12,4),
    valor_total         NUMERIC(12,2),
    quantidade_recebida NUMERIC(12,3) DEFAULT 0 -- pode receber parcial
);

-- Agora posso adicionar a FK de movimentos para pedidos (ambas as tabelas existem)
ALTER TABLE movimentos_estoque ADD CONSTRAINT fk_mov_pedido
    FOREIGN KEY (pedido_id) REFERENCES pedidos_compra(id);


-- =============================================================================
--  MÓDULO: DOCUMENTOS CLÍNICOS
--
--  Receitas, atestados e radiografias são documentos com valor legal.
--  Mantive as tabelas simples mas com os campos obrigatórios pra conformidade.
-- =============================================================================

-- Receitas médicas — guardei o texto livre em medicamentos/posologia
-- porque os medicamentos variam muito e uma tabela estruturada seria over-engineering
CREATE TABLE receitas (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    consulta_id   INT REFERENCES consultas(id),
    dentista_id   INT NOT NULL REFERENCES dentistas(id),
    data_emissao  DATE DEFAULT CURRENT_DATE,
    tipo          VARCHAR(50) DEFAULT 'SIMPLES', -- SIMPLES ou CONTROLE_ESPECIAL (tarja preta)
    medicamentos  TEXT NOT NULL,
    posologia     TEXT,
    observacoes   TEXT,
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

-- Atestados de afastamento — o campo CID é o código da doença (Classificação Internacional)
CREATE TABLE atestados (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    consulta_id   INT REFERENCES consultas(id),
    dentista_id   INT NOT NULL REFERENCES dentistas(id),
    data_emissao  DATE DEFAULT CURRENT_DATE,
    tipo          VARCHAR(50) DEFAULT 'AFASTAMENTO',
    dias_afastamento        INT,
    data_inicio_afastamento DATE,
    cid           VARCHAR(20), -- ex: K01.1 = dente incluso
    descricao     TEXT,
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

-- Radiografias — o arquivo em si fica no storage (S3, etc.), aqui guardo a referência
CREATE TABLE radiografias (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    consulta_id   INT REFERENCES consultas(id),
    dentista_id   INT REFERENCES dentistas(id),
    tipo          VARCHAR(50),  -- PERIAPICAL, PANORAMICA, BITE-WING, CBCT, CEFALOMETRIA
    regiao        VARCHAR(100),
    numero_dente  SMALLINT,
    data_realizacao DATE DEFAULT CURRENT_DATE,
    arquivo_url   TEXT,         -- URL no bucket de storage
    laudo         TEXT,
    laudado_por   INT REFERENCES dentistas(id), -- pode ser um radiologista diferente
    laudado_em    TIMESTAMPTZ,
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

-- Documentos genéricos: exames de sangue, laudos externos, fotos clínicas...
CREATE TABLE documentos (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    tipo          VARCHAR(100) NOT NULL,
    descricao     VARCHAR(200),
    arquivo_url   TEXT NOT NULL,
    tamanho_bytes BIGINT,
    mime_type     VARCHAR(100),
    enviado_por   INT REFERENCES funcionarios(id),
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: COMUNICAÇÃO
--
--  Notificações automáticas (lembretes de consulta, cobranças, aniversários)
--  são essenciais pra reduzir faltas e melhorar o relacionamento com o paciente.
--  Aqui guardo o histórico de tudo que foi enviado (ou tentou ser enviado).
-- =============================================================================

CREATE TABLE notificacoes (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    paciente_id INT REFERENCES pacientes(id),
    tipo        VARCHAR(50) NOT NULL,  -- LEMBRETE, RETORNO, COBRANCA, ANIVERSARIO
    canal       VARCHAR(30) NOT NULL,  -- SMS, EMAIL, WHATSAPP, PUSH
    titulo      VARCHAR(200),
    mensagem    TEXT NOT NULL,
    agendada_para TIMESTAMPTZ,         -- quando deve ser enviada
    enviada_em    TIMESTAMPTZ,         -- quando foi de fato enviada
    status        VARCHAR(20) DEFAULT 'PENDENTE',
    erro_descricao TEXT,               -- se falhou, por quê?
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

-- Retornos programados: quando o dentista indica que o paciente deve voltar
-- em X dias. Isso alimenta lembretes automáticos de retorno.
CREATE TABLE retornos (
    id                  SERIAL PRIMARY KEY,
    consulta_origem_id  INT NOT NULL REFERENCES consultas(id),
    paciente_id         INT NOT NULL REFERENCES pacientes(id),
    dentista_id         INT NOT NULL REFERENCES dentistas(id),
    data_sugerida       DATE,
    prazo_dias          INT DEFAULT 180,   -- em quantos dias deve retornar
    motivo              TEXT,
    agendado            BOOLEAN DEFAULT FALSE,
    consulta_retorno_id INT REFERENCES consultas(id), -- qual consulta foi o retorno
    criado_em           TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  MÓDULO: AUDITORIA
--
--  Auditoria é o que permite saber "quem alterou o quê e quando".
--  Implementei via triggers (ver 05_triggers.sql) que gravam automaticamente
--  em log_auditoria sempre que algo muda nas tabelas críticas.
--
--  O campo dados_antigos/dados_novos usa JSONB — armazena o registro inteiro
--  antes e depois da mudança. Assim dá pra reconstruir qualquer estado histórico.
-- =============================================================================

CREATE TABLE log_auditoria (
    id           BIGSERIAL PRIMARY KEY, -- BIGSERIAL porque pode crescer muito
    tabela       VARCHAR(100) NOT NULL,
    operacao     CHAR(1) NOT NULL,       -- I = Insert, U = Update, D = Delete
    registro_id  INT,
    dados_antigos JSONB,                 -- estado anterior (NULL em inserts)
    dados_novos   JSONB,                 -- estado novo (NULL em deletes)
    usuario_id   INT REFERENCES funcionarios(id),
    ip_address   INET,                   -- endereço IP de onde veio a ação
    criado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- Log de acesso: registra logins, ações no sistema, tentativas falhas
CREATE TABLE log_acesso (
    id         BIGSERIAL PRIMARY KEY,
    usuario_id INT REFERENCES funcionarios(id),
    acao       VARCHAR(100),
    modulo     VARCHAR(100),
    ip_address INET,
    user_agent TEXT,      -- qual navegador/app foi usado
    sucesso    BOOLEAN DEFAULT TRUE,
    criado_em  TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================================
--  COMENTÁRIOS DAS TABELAS
--
--  Os COMMENTs ficam visíveis em ferramentas como DBeaver, pgAdmin e \d+ no psql.
--  Boa prática pra documentar o banco sem depender de docs externos.
-- =============================================================================

COMMENT ON TABLE clinica           IS 'Dados da clínica. Suporta múltiplas unidades.';
COMMENT ON TABLE salas             IS 'Consultórios e salas de atendimento por unidade.';
COMMENT ON TABLE equipamentos      IS 'Patrimônio da clínica com controle de manutenção.';
COMMENT ON TABLE especialidades    IS 'Especialidades odontológicas reconhecidas pelo CFO.';
COMMENT ON TABLE procedimentos     IS 'Catálogo de procedimentos com valores e duração. Códigos TUSS e CBHPM para convênios.';
COMMENT ON TABLE pacientes         IS 'Cadastro central de pacientes.';
COMMENT ON TABLE paciente_telefones IS 'Múltiplos telefones por paciente, com tipo e flag de principal.';
COMMENT ON TABLE paciente_alergias IS 'Alergias do paciente — dado crítico de segurança clínica.';
COMMENT ON TABLE cargos            IS 'Cargos ocupados pelos funcionários.';
COMMENT ON TABLE funcionarios      IS 'Todos os colaboradores da clínica, com ou sem CRO.';
COMMENT ON TABLE dentistas         IS 'Dados profissionais dos dentistas (CRO, comissão). Pode ou não ter vínculo como funcionário.';
COMMENT ON TABLE dentista_especialidades IS 'Especialidades de cada dentista.';
COMMENT ON TABLE dentista_disponibilidade IS 'Grade semanal de horários de atendimento por dentista.';
COMMENT ON TABLE convenios         IS 'Planos de saúde e convênios odontológicos aceitos.';
COMMENT ON TABLE convenio_procedimentos IS 'Valores e regras de cada procedimento por convênio.';
COMMENT ON TABLE consultas         IS 'Agenda e histórico de atendimentos. Tabela mais acessada do sistema.';
COMMENT ON TABLE agenda_bloqueio   IS 'Bloqueios de horário na agenda (férias, reuniões, manutenção).';
COMMENT ON TABLE lista_espera      IS 'Pacientes aguardando horário disponível.';
COMMENT ON TABLE prontuarios       IS 'Prontuário eletrônico — gerado automaticamente ao cadastrar o paciente.';
COMMENT ON TABLE anamnese          IS 'Ficha de saúde geral do paciente. Base para decisões clínicas.';
COMMENT ON TABLE odontograma       IS 'Estado de cada dente (notação FDI). Gerado com 32 dentes ao criar o prontuário.';
COMMENT ON TABLE odontograma_faces IS 'Estado de cada face dentária para granularidade clínica total.';
COMMENT ON TABLE evolucoes         IS 'Registro clínico do que foi realizado em cada consulta.';
COMMENT ON TABLE planos_tratamento IS 'Planejamento de tratamentos com múltiplos procedimentos e valores.';
COMMENT ON TABLE itens_plano       IS 'Procedimentos do plano com valor_total calculado automaticamente.';
COMMENT ON TABLE orcamentos        IS 'Proposta financeira formal para o paciente.';
COMMENT ON TABLE pagamentos        IS 'Registro central de cobranças. Relacionado a consultas ou planos.';
COMMENT ON TABLE parcelas          IS 'Parcelamento de um pagamento. Permite controle de inadimplência por parcela.';
COMMENT ON TABLE comissoes         IS 'Comissões dos dentistas calculadas automaticamente ao confirmar pagamento.';
COMMENT ON TABLE materiais         IS 'Catálogo de insumos e materiais odontológicos.';
COMMENT ON TABLE lotes_material    IS 'Lotes de compra com validade — permite controle FIFO e rastreabilidade.';
COMMENT ON TABLE movimentos_estoque IS 'Histórico completo de entradas e saídas de estoque.';
COMMENT ON TABLE pedidos_compra    IS 'Pedidos a fornecedores, gerados a partir do ponto de reposição.';
COMMENT ON TABLE receitas          IS 'Receitas médicas emitidas pelos dentistas.';
COMMENT ON TABLE atestados         IS 'Atestados de afastamento com CID.';
COMMENT ON TABLE radiografias      IS 'Exames de imagem com referência ao arquivo e laudo.';
COMMENT ON TABLE notificacoes      IS 'Histórico de notificações enviadas (SMS, WhatsApp, e-mail).';
COMMENT ON TABLE retornos          IS 'Retornos programados para acompanhamento dos tratamentos.';
COMMENT ON TABLE log_auditoria     IS 'Auditoria automática de INSERT/UPDATE/DELETE nas tabelas críticas.';
COMMENT ON TABLE log_acesso        IS 'Registro de acessos e ações dos usuários no sistema.';
