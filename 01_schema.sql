-- =============================================================================
--  01_schema.sql — Definição de todas as tabelas do sistema OdontoRecife
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ENUMs
CREATE TYPE sexo_enum            AS ENUM ('M', 'F', 'OUTRO');
CREATE TYPE estado_civil_enum    AS ENUM ('SOLTEIRO','CASADO','DIVORCIADO','VIUVO','UNIAO_ESTAVEL','OUTRO');
CREATE TYPE tipo_telefone_enum   AS ENUM ('CELULAR','RESIDENCIAL','COMERCIAL','WHATSAPP');
CREATE TYPE status_consulta_enum AS ENUM ('AGENDADA','CONFIRMADA','EM_ATENDIMENTO','CONCLUIDA','CANCELADA','FALTOU','REMARCADA');
CREATE TYPE tipo_pagamento_enum  AS ENUM ('DINHEIRO','CARTAO_DEBITO','CARTAO_CREDITO','PIX','BOLETO','TRANSFERENCIA','CONVENIO','CHEQUE');
CREATE TYPE status_pagamento_enum AS ENUM ('PENDENTE','PARCIAL','PAGO','ATRASADO','CANCELADO','ESTORNADO');
CREATE TYPE status_plano_enum    AS ENUM ('ATIVO','CONCLUIDO','CANCELADO','SUSPENSO','ORCAMENTO');
CREATE TYPE face_dente_enum      AS ENUM ('VESTIBULAR','LINGUAL','MESIAL','DISTAL','OCLUSAL','INCISAL','CERVICAL','RAIZ');
CREATE TYPE status_dente_enum    AS ENUM ('HÍGIDO','CARIADO','RESTAURADO','EXTRAÍDO','AUSENTE','IMPLANTE','COROA','ENDODONTIA','FRATURADO','MANCHADO');
CREATE TYPE tipo_movimento_estoque_enum AS ENUM ('ENTRADA','SAIDA','AJUSTE','DEVOLUCAO','VENCIMENTO');
CREATE TYPE prioridade_enum      AS ENUM ('BAIXA','MEDIA','ALTA','URGENTE');
CREATE TYPE turno_enum           AS ENUM ('MANHA','TARDE','NOITE','INTEGRAL');

-- CLINICA
CREATE TABLE clinica (
    id              SERIAL PRIMARY KEY,
    razao_social    VARCHAR(200) NOT NULL,
    nome_fantasia   VARCHAR(200),
    cnpj            CHAR(18) UNIQUE NOT NULL,
    cro_pj          VARCHAR(20),
    email           VARCHAR(150),
    site            VARCHAR(150),
    logo_url        TEXT,
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
    horario_abertura    TIME DEFAULT '08:00',
    horario_fechamento  TIME DEFAULT '18:00',
    intervalo_consulta  INT  DEFAULT 30,
    ativo         BOOLEAN     DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE salas (
    id          SERIAL PRIMARY KEY,
    clinica_id  INT NOT NULL REFERENCES clinica(id),
    nome        VARCHAR(50) NOT NULL,
    descricao   TEXT,
    capacidade  INT     DEFAULT 1,
    ativa       BOOLEAN DEFAULT TRUE,
    criado_em   TIMESTAMPTZ DEFAULT NOW()
);

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

-- ESPECIALIDADES E PROCEDIMENTOS
CREATE TABLE especialidades (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativa     BOOLEAN DEFAULT TRUE
);

CREATE TABLE procedimentos (
    id               SERIAL PRIMARY KEY,
    especialidade_id INT REFERENCES especialidades(id),
    codigo_tuss      VARCHAR(20),
    codigo_cbhpm     VARCHAR(20),
    nome             VARCHAR(200) NOT NULL,
    descricao        TEXT,
    duracao_minutos  INT           DEFAULT 30,
    valor_base       NUMERIC(12,2) NOT NULL DEFAULT 0,
    valor_minimo     NUMERIC(12,2),
    valor_maximo     NUMERIC(12,2),
    requer_rx        BOOLEAN DEFAULT FALSE,
    requer_anestesia BOOLEAN DEFAULT FALSE,
    ativo            BOOLEAN DEFAULT TRUE,
    criado_em        TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- PACIENTES
CREATE TABLE pacientes (
    id              SERIAL PRIMARY KEY,
    clinica_id      INT NOT NULL REFERENCES clinica(id),
    nome_completo   VARCHAR(200) NOT NULL,
    cpf             CHAR(14) UNIQUE,
    rg              VARCHAR(20),
    data_nascimento DATE,
    sexo            sexo_enum,
    estado_civil    estado_civil_enum,
    profissao       VARCHAR(100),
    nacionalidade   VARCHAR(80) DEFAULT 'Brasileiro(a)',
    logradouro      VARCHAR(200),
    numero          VARCHAR(10),
    complemento     VARCHAR(100),
    bairro          VARCHAR(100),
    cidade          VARCHAR(100) DEFAULT 'Recife',
    estado          CHAR(2)      DEFAULT 'PE',
    cep             CHAR(9),
    email           VARCHAR(150),
    convenio_id     INT,
    numero_carteirinha   VARCHAR(50),
    validade_carteirinha DATE,
    responsavel_nome       VARCHAR(200),
    responsavel_cpf        CHAR(14),
    responsavel_parentesco VARCHAR(50),
    como_conheceu   VARCHAR(100),
    observacoes     TEXT,
    foto_url        TEXT,
    ativo                BOOLEAN DEFAULT TRUE,
    primeiro_atendimento DATE,
    criado_em            TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE paciente_telefones (
    id          SERIAL PRIMARY KEY,
    paciente_id INT NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    tipo        tipo_telefone_enum DEFAULT 'CELULAR',
    numero      VARCHAR(20) NOT NULL,
    principal   BOOLEAN     DEFAULT FALSE,
    observacao  VARCHAR(100)
);

CREATE TABLE paciente_alergias (
    id            SERIAL PRIMARY KEY,
    paciente_id   INT NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    substancia    VARCHAR(200) NOT NULL,
    reacao        TEXT,
    gravidade     VARCHAR(50),
    confirmado    BOOLEAN     DEFAULT FALSE,
    registrado_em TIMESTAMPTZ DEFAULT NOW()
);

-- FUNCIONARIOS E DENTISTAS
CREATE TABLE cargos (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativo     BOOLEAN DEFAULT TRUE
);

CREATE TABLE funcionarios (
    id              SERIAL PRIMARY KEY,
    clinica_id      INT NOT NULL REFERENCES clinica(id),
    cargo_id        INT REFERENCES cargos(id),
    nome_completo   VARCHAR(200) NOT NULL,
    cpf             CHAR(14) UNIQUE NOT NULL,
    rg              VARCHAR(20),
    data_nascimento DATE,
    sexo            sexo_enum,
    email           VARCHAR(150),
    telefone        VARCHAR(20),
    logradouro      VARCHAR(200),
    numero          VARCHAR(10),
    complemento     VARCHAR(100),
    bairro          VARCHAR(100),
    cidade          VARCHAR(100) DEFAULT 'Recife',
    estado          CHAR(2)      DEFAULT 'PE',
    cep             CHAR(9),
    data_admissao   DATE NOT NULL,
    data_demissao   DATE,
    salario         NUMERIC(12,2),
    turno           turno_enum DEFAULT 'INTEGRAL',
    usuario_sistema VARCHAR(50) UNIQUE,
    ativo           BOOLEAN     DEFAULT TRUE,
    criado_em       TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dentistas (
    id             SERIAL PRIMARY KEY,
    funcionario_id INT UNIQUE REFERENCES funcionarios(id),
    cro_numero     VARCHAR(20) NOT NULL,
    cro_estado     CHAR(2)     DEFAULT 'PE',
    nome_completo  VARCHAR(200),
    cpf            CHAR(14),
    email          VARCHAR(150),
    telefone       VARCHAR(20),
    comissao_percentual NUMERIC(5,2) DEFAULT 0,
    cor_agenda     CHAR(7) DEFAULT '#3B82F6',
    ativo          BOOLEAN     DEFAULT TRUE,
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dentista_especialidades (
    dentista_id      INT NOT NULL REFERENCES dentistas(id) ON DELETE CASCADE,
    especialidade_id INT NOT NULL REFERENCES especialidades(id),
    principal        BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (dentista_id, especialidade_id)
);

CREATE TABLE dentista_disponibilidade (
    id          SERIAL PRIMARY KEY,
    dentista_id INT NOT NULL REFERENCES dentistas(id) ON DELETE CASCADE,
    dia_semana  SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL,
    hora_fim    TIME NOT NULL,
    sala_id     INT REFERENCES salas(id),
    ativo       BOOLEAN DEFAULT TRUE
);

-- CONVENIOS
CREATE TABLE convenios (
    id           SERIAL PRIMARY KEY,
    nome         VARCHAR(150) NOT NULL,
    razao_social VARCHAR(200),
    cnpj         CHAR(18),
    ans_registro VARCHAR(20),
    email        VARCHAR(150),
    telefone     VARCHAR(20),
    site         VARCHAR(150),
    observacoes  TEXT,
    ativo        BOOLEAN     DEFAULT TRUE,
    criado_em    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE convenio_procedimentos (
    id              SERIAL PRIMARY KEY,
    convenio_id     INT NOT NULL REFERENCES convenios(id),
    procedimento_id INT NOT NULL REFERENCES procedimentos(id),
    codigo_convenio VARCHAR(30),
    valor_convenio  NUMERIC(12,2) NOT NULL,
    carencia_dias   INT DEFAULT 0,
    limite_anual    INT,
    vigencia_inicio DATE,
    vigencia_fim    DATE,
    UNIQUE(convenio_id, procedimento_id)
);

ALTER TABLE pacientes ADD CONSTRAINT fk_paciente_convenio
    FOREIGN KEY (convenio_id) REFERENCES convenios(id);

-- AGENDAMENTO
CREATE TABLE consultas (
    id              SERIAL PRIMARY KEY,
    clinica_id      INT NOT NULL REFERENCES clinica(id),
    paciente_id     INT NOT NULL REFERENCES pacientes(id),
    dentista_id     INT NOT NULL REFERENCES dentistas(id),
    sala_id         INT REFERENCES salas(id),
    procedimento_id INT REFERENCES procedimentos(id),
    data_hora_inicio TIMESTAMPTZ NOT NULL,
    data_hora_fim    TIMESTAMPTZ,
    duracao_minutos  INT DEFAULT 30,
    status           status_consulta_enum DEFAULT 'AGENDADA',
    prioridade       prioridade_enum      DEFAULT 'MEDIA',
    valor_cobrado    NUMERIC(12,2),
    convenio_id      INT REFERENCES convenios(id),
    agendado_por     INT REFERENCES funcionarios(id),
    confirmado_em    TIMESTAMPTZ,
    chegou_em        TIMESTAMPTZ,
    iniciou_em       TIMESTAMPTZ,
    concluiu_em      TIMESTAMPTZ,
    motivo_cancelamento TEXT,
    observacoes         TEXT,
    criado_em           TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE agenda_bloqueio (
    id               SERIAL PRIMARY KEY,
    dentista_id      INT REFERENCES dentistas(id),
    sala_id          INT REFERENCES salas(id),
    data_hora_inicio TIMESTAMPTZ NOT NULL,
    data_hora_fim    TIMESTAMPTZ NOT NULL,
    motivo           VARCHAR(200),
    recorrente       BOOLEAN DEFAULT FALSE,
    criado_por       INT REFERENCES funcionarios(id),
    criado_em        TIMESTAMPTZ DEFAULT NOW()
);

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
    atendido          BOOLEAN     DEFAULT FALSE,
    criado_em         TIMESTAMPTZ DEFAULT NOW()
);

-- PRONTUARIO
CREATE TABLE prontuarios (
    id                      SERIAL PRIMARY KEY,
    paciente_id             INT NOT NULL UNIQUE REFERENCES pacientes(id),
    numero                  VARCHAR(20) UNIQUE NOT NULL,
    data_abertura           DATE DEFAULT CURRENT_DATE,
    dentista_responsavel_id INT REFERENCES dentistas(id),
    observacoes_gerais      TEXT,
    criado_em               TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE anamnese (
    id                    SERIAL PRIMARY KEY,
    prontuario_id         INT NOT NULL REFERENCES prontuarios(id),
    data_preenchimento    DATE DEFAULT CURRENT_DATE,
    dentista_id           INT REFERENCES dentistas(id),
    queixa_principal      TEXT,
    historia_doenca_atual TEXT,
    pressao_arterial      VARCHAR(20),
    frequencia_cardiaca   INT,
    peso_kg               NUMERIC(6,2),
    altura_cm             NUMERIC(5,2),
    hipertensao  BOOLEAN DEFAULT FALSE,
    diabetes     BOOLEAN DEFAULT FALSE,
    cardiopatia  BOOLEAN DEFAULT FALSE,
    asma         BOOLEAN DEFAULT FALSE,
    epilepsia    BOOLEAN DEFAULT FALSE,
    hiv          BOOLEAN DEFAULT FALSE,
    hepatite     BOOLEAN DEFAULT FALSE,
    doenca_renal BOOLEAN DEFAULT FALSE,
    coagulopatia BOOLEAN DEFAULT FALSE,
    osteoporose  BOOLEAN DEFAULT FALSE,
    gestante     BOOLEAN DEFAULT FALSE,
    semanas_gestacao     INT,
    usa_medicamentos     BOOLEAN DEFAULT FALSE,
    medicamentos_desc    TEXT,
    fuma                 BOOLEAN DEFAULT FALSE,
    consome_alcool       BOOLEAN DEFAULT FALSE,
    bruxismo             BOOLEAN DEFAULT FALSE,
    ultima_consulta_odonto DATE,
    medo_dentista          BOOLEAN DEFAULT FALSE,
    tratamentos_anteriores TEXT,
    observacoes            TEXT,
    assinatura_paciente    BOOLEAN DEFAULT FALSE,
    criado_em              TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE odontograma (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT      NOT NULL REFERENCES prontuarios(id),
    numero_dente  SMALLINT NOT NULL CHECK (numero_dente BETWEEN 11 AND 88),
    status        status_dente_enum DEFAULT 'HÍGIDO',
    observacao    TEXT,
    atualizado_em TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(prontuario_id, numero_dente)
);

CREATE TABLE odontograma_faces (
    id              SERIAL PRIMARY KEY,
    odontograma_id  INT NOT NULL REFERENCES odontograma(id) ON DELETE CASCADE,
    face            face_dente_enum NOT NULL,
    status          status_dente_enum DEFAULT 'HÍGIDO',
    procedimento_id INT REFERENCES procedimentos(id),
    cor_material    VARCHAR(50),
    observacao      TEXT,
    data_registro   DATE DEFAULT CURRENT_DATE,
    UNIQUE(odontograma_id, face)
);

CREATE TABLE evolucoes (
    id                       SERIAL PRIMARY KEY,
    prontuario_id            INT NOT NULL REFERENCES prontuarios(id),
    consulta_id              INT REFERENCES consultas(id),
    dentista_id              INT NOT NULL REFERENCES dentistas(id),
    data_evolucao            TIMESTAMPTZ DEFAULT NOW(),
    descricao                TEXT NOT NULL,
    procedimentos_realizados TEXT,
    dentes_tratados          VARCHAR(200),
    proximos_passos          TEXT,
    criado_em                TIMESTAMPTZ DEFAULT NOW()
);

-- PLANOS DE TRATAMENTO
CREATE TABLE planos_tratamento (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    dentista_id   INT NOT NULL REFERENCES dentistas(id),
    titulo        VARCHAR(200),
    status        status_plano_enum DEFAULT 'ORCAMENTO',
    data_inicio           DATE,
    data_previsao_fim     DATE,
    data_conclusao        DATE,
    valor_total           NUMERIC(12,2) DEFAULT 0,
    desconto_percentual   NUMERIC(5,2)  DEFAULT 0,
    desconto_valor        NUMERIC(12,2) DEFAULT 0,
    valor_final           NUMERIC(12,2) DEFAULT 0,
    observacoes           TEXT,
    aprovado_em           TIMESTAMPTZ,
    criado_em             TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE itens_plano (
    id              SERIAL PRIMARY KEY,
    plano_id        INT NOT NULL REFERENCES planos_tratamento(id) ON DELETE CASCADE,
    procedimento_id INT NOT NULL REFERENCES procedimentos(id),
    numero_dente    SMALLINT,
    face_dente      face_dente_enum,
    quantidade      INT           DEFAULT 1,
    valor_unitario  NUMERIC(12,2) NOT NULL,
    valor_total     NUMERIC(12,2) GENERATED ALWAYS AS (quantidade * valor_unitario) STORED,
    ordem_execucao  INT     DEFAULT 1,
    status          VARCHAR(30) DEFAULT 'PENDENTE',
    consulta_id     INT REFERENCES consultas(id),
    concluido_em    TIMESTAMPTZ,
    observacoes     TEXT
);

-- FINANCEIRO
CREATE TABLE orcamentos (
    id            SERIAL PRIMARY KEY,
    clinica_id    INT NOT NULL REFERENCES clinica(id),
    paciente_id   INT NOT NULL REFERENCES pacientes(id),
    dentista_id   INT REFERENCES dentistas(id),
    plano_id      INT REFERENCES planos_tratamento(id),
    numero        VARCHAR(20) UNIQUE NOT NULL,
    data_emissao  DATE DEFAULT CURRENT_DATE,
    validade_dias INT  DEFAULT 30,
    valor_bruto   NUMERIC(12,2) DEFAULT 0,
    desconto_valor NUMERIC(12,2) DEFAULT 0,
    valor_liquido  NUMERIC(12,2) DEFAULT 0,
    status         VARCHAR(20)   DEFAULT 'PENDENTE',
    observacoes    TEXT,
    aprovado_em    TIMESTAMPTZ,
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE pagamentos (
    id              SERIAL PRIMARY KEY,
    clinica_id      INT NOT NULL REFERENCES clinica(id),
    paciente_id     INT NOT NULL REFERENCES pacientes(id),
    consulta_id     INT REFERENCES consultas(id),
    plano_id        INT REFERENCES planos_tratamento(id),
    orcamento_id    INT REFERENCES orcamentos(id),
    numero_recibo   VARCHAR(30) UNIQUE,
    descricao       TEXT,
    valor_total     NUMERIC(12,2) NOT NULL,
    valor_desconto  NUMERIC(12,2) DEFAULT 0,
    valor_pago      NUMERIC(12,2) DEFAULT 0,
    status          status_pagamento_enum DEFAULT 'PENDENTE',
    forma_pagamento tipo_pagamento_enum,
    numero_parcelas INT  DEFAULT 1,
    data_vencimento DATE,
    data_pagamento  DATE,
    convenio_id     INT REFERENCES convenios(id),
    valor_convenio  NUMERIC(12,2) DEFAULT 0,
    numero_guia     VARCHAR(50),
    registrado_por  INT REFERENCES funcionarios(id),
    observacoes     TEXT,
    criado_em       TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE parcelas (
    id               SERIAL PRIMARY KEY,
    pagamento_id     INT NOT NULL REFERENCES pagamentos(id) ON DELETE CASCADE,
    numero_parcela   INT NOT NULL,
    valor            NUMERIC(12,2) NOT NULL,
    data_vencimento  DATE NOT NULL,
    data_pagamento   DATE,
    forma_pagamento  tipo_pagamento_enum,
    status           status_pagamento_enum DEFAULT 'PENDENTE',
    codigo_transacao VARCHAR(100),
    observacoes      TEXT
);

CREATE TABLE comissoes (
    id             SERIAL PRIMARY KEY,
    dentista_id    INT NOT NULL REFERENCES dentistas(id),
    pagamento_id   INT NOT NULL REFERENCES pagamentos(id),
    consulta_id    INT REFERENCES consultas(id),
    valor_base     NUMERIC(12,2) NOT NULL,
    percentual     NUMERIC(5,2)  NOT NULL,
    valor_comissao NUMERIC(12,2) NOT NULL,
    competencia    DATE NOT NULL,
    pago           BOOLEAN DEFAULT FALSE,
    data_pagamento DATE,
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

-- ESTOQUE
CREATE TABLE categorias_material (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativa     BOOLEAN DEFAULT TRUE
);

CREATE TABLE fornecedores (
    id                 SERIAL PRIMARY KEY,
    razao_social       VARCHAR(200) NOT NULL,
    nome_fantasia      VARCHAR(200),
    cnpj               CHAR(18) UNIQUE,
    inscricao_estadual VARCHAR(30),
    email              VARCHAR(150),
    telefone           VARCHAR(20),
    whatsapp           VARCHAR(20),
    site               VARCHAR(150),
    logradouro         VARCHAR(200),
    numero             VARCHAR(10),
    complemento        VARCHAR(100),
    bairro             VARCHAR(100),
    cidade             VARCHAR(100),
    estado             CHAR(2),
    cep                CHAR(9),
    contato_nome       VARCHAR(150),
    contato_email      VARCHAR(150),
    prazo_entrega_dias INT,
    condicao_pagamento VARCHAR(100),
    ativo              BOOLEAN DEFAULT TRUE,
    observacoes        TEXT,
    criado_em          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE materiais (
    id                      SERIAL PRIMARY KEY,
    categoria_id            INT REFERENCES categorias_material(id),
    fornecedor_preferido_id INT REFERENCES fornecedores(id),
    nome                    VARCHAR(200) NOT NULL,
    descricao               TEXT,
    codigo_interno          VARCHAR(50) UNIQUE,
    codigo_fabricante       VARCHAR(50),
    unidade_medida          VARCHAR(20) NOT NULL DEFAULT 'UN',
    estoque_atual           NUMERIC(12,3) DEFAULT 0,
    estoque_minimo          NUMERIC(12,3) DEFAULT 0,
    estoque_maximo          NUMERIC(12,3),
    ponto_reposicao         NUMERIC(12,3),
    valor_custo             NUMERIC(12,2),
    valor_venda             NUMERIC(12,2),
    requer_controle_lote    BOOLEAN DEFAULT FALSE,
    controlado_anvisa       BOOLEAN DEFAULT FALSE,
    ativo                   BOOLEAN DEFAULT TRUE,
    criado_em               TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lotes_material (
    id                 SERIAL PRIMARY KEY,
    material_id        INT NOT NULL REFERENCES materiais(id),
    fornecedor_id      INT REFERENCES fornecedores(id),
    numero_lote        VARCHAR(50),
    numero_nota_fiscal VARCHAR(30),
    quantidade_entrada NUMERIC(12,3) NOT NULL,
    quantidade_atual   NUMERIC(12,3) NOT NULL,
    data_fabricacao    DATE,
    data_validade      DATE,
    valor_unitario     NUMERIC(12,4),
    criado_em          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE movimentos_estoque (
    id             SERIAL PRIMARY KEY,
    material_id    INT NOT NULL REFERENCES materiais(id),
    lote_id        INT REFERENCES lotes_material(id),
    tipo           tipo_movimento_estoque_enum NOT NULL,
    quantidade     NUMERIC(12,3) NOT NULL,
    valor_unitario NUMERIC(12,4),
    valor_total    NUMERIC(12,2),
    consulta_id    INT REFERENCES consultas(id),
    pedido_id      INT,
    motivo         TEXT,
    registrado_por INT REFERENCES funcionarios(id),
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE pedidos_compra (
    id                    SERIAL PRIMARY KEY,
    clinica_id            INT NOT NULL REFERENCES clinica(id),
    fornecedor_id         INT NOT NULL REFERENCES fornecedores(id),
    numero_pedido         VARCHAR(30) UNIQUE NOT NULL,
    data_pedido           DATE DEFAULT CURRENT_DATE,
    data_previsao_entrega DATE,
    data_entrega          DATE,
    status                VARCHAR(30) DEFAULT 'PENDENTE',
    valor_total           NUMERIC(12,2) DEFAULT 0,
    observacoes           TEXT,
    criado_por            INT REFERENCES funcionarios(id),
    criado_em             TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE itens_pedido (
    id                  SERIAL PRIMARY KEY,
    pedido_id           INT NOT NULL REFERENCES pedidos_compra(id) ON DELETE CASCADE,
    material_id         INT NOT NULL REFERENCES materiais(id),
    quantidade          NUMERIC(12,3) NOT NULL,
    valor_unitario      NUMERIC(12,4),
    valor_total         NUMERIC(12,2),
    quantidade_recebida NUMERIC(12,3) DEFAULT 0
);

ALTER TABLE movimentos_estoque ADD CONSTRAINT fk_mov_pedido
    FOREIGN KEY (pedido_id) REFERENCES pedidos_compra(id);

-- DOCUMENTOS
CREATE TABLE receitas (
    id            SERIAL PRIMARY KEY,
    prontuario_id INT NOT NULL REFERENCES prontuarios(id),
    consulta_id   INT REFERENCES consultas(id),
    dentista_id   INT NOT NULL REFERENCES dentistas(id),
    data_emissao  DATE DEFAULT CURRENT_DATE,
    tipo          VARCHAR(50) DEFAULT 'SIMPLES',
    medicamentos  TEXT NOT NULL,
    posologia     TEXT,
    observacoes   TEXT,
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE atestados (
    id                      SERIAL PRIMARY KEY,
    prontuario_id           INT NOT NULL REFERENCES prontuarios(id),
    consulta_id             INT REFERENCES consultas(id),
    dentista_id             INT NOT NULL REFERENCES dentistas(id),
    data_emissao            DATE DEFAULT CURRENT_DATE,
    tipo                    VARCHAR(50) DEFAULT 'AFASTAMENTO',
    dias_afastamento        INT,
    data_inicio_afastamento DATE,
    cid                     VARCHAR(20),
    descricao               TEXT,
    criado_em               TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE radiografias (
    id              SERIAL PRIMARY KEY,
    prontuario_id   INT NOT NULL REFERENCES prontuarios(id),
    consulta_id     INT REFERENCES consultas(id),
    dentista_id     INT REFERENCES dentistas(id),
    tipo            VARCHAR(50),
    regiao          VARCHAR(100),
    numero_dente    SMALLINT,
    data_realizacao DATE DEFAULT CURRENT_DATE,
    arquivo_url     TEXT,
    laudo           TEXT,
    laudado_por     INT REFERENCES dentistas(id),
    laudado_em      TIMESTAMPTZ,
    criado_em       TIMESTAMPTZ DEFAULT NOW()
);

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

-- COMUNICACAO
CREATE TABLE notificacoes (
    id            SERIAL PRIMARY KEY,
    clinica_id    INT NOT NULL REFERENCES clinica(id),
    paciente_id   INT REFERENCES pacientes(id),
    tipo          VARCHAR(50) NOT NULL,
    canal         VARCHAR(30) NOT NULL,
    titulo        VARCHAR(200),
    mensagem      TEXT NOT NULL,
    agendada_para TIMESTAMPTZ,
    enviada_em    TIMESTAMPTZ,
    status        VARCHAR(20) DEFAULT 'PENDENTE',
    erro_descricao TEXT,
    criado_em      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE retornos (
    id                  SERIAL PRIMARY KEY,
    consulta_origem_id  INT NOT NULL REFERENCES consultas(id),
    paciente_id         INT NOT NULL REFERENCES pacientes(id),
    dentista_id         INT NOT NULL REFERENCES dentistas(id),
    data_sugerida       DATE,
    prazo_dias          INT DEFAULT 180,
    motivo              TEXT,
    agendado            BOOLEAN DEFAULT FALSE,
    consulta_retorno_id INT REFERENCES consultas(id),
    criado_em           TIMESTAMPTZ DEFAULT NOW()
);

-- AUDITORIA
CREATE TABLE log_auditoria (
    id            BIGSERIAL PRIMARY KEY,
    tabela        VARCHAR(100) NOT NULL,
    operacao      CHAR(1) NOT NULL,
    registro_id   INT,
    dados_antigos JSONB,
    dados_novos   JSONB,
    usuario_id    INT REFERENCES funcionarios(id),
    ip_address    INET,
    criado_em     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE log_acesso (
    id         BIGSERIAL PRIMARY KEY,
    usuario_id INT REFERENCES funcionarios(id),
    acao       VARCHAR(100),
    modulo     VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    sucesso    BOOLEAN DEFAULT TRUE,
    criado_em  TIMESTAMPTZ DEFAULT NOW()
);