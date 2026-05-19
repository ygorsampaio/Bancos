-- =============================================================================
--  03_views.sql
--  Views para relatórios e consultas frequentes
--
--  View é basicamente uma query com nome. Em vez de escrever um SELECT
--  enorme toda vez que precisar, você cria uma view e consulta ela como
--  se fosse uma tabela.
--
--  Usei CREATE OR REPLACE VIEW em todas, o que permite atualizar a view
--  sem precisar dropar e recriar — útil quando tem permissões configuradas.
--
--  Uma coisa importante: views no Postgres são recalculadas toda vez que
--  você consulta. Se uma view for muito pesada e consultada com frequência,
--  considere transformar em MATERIALIZED VIEW (guarda o resultado em cache).
--
--  Ordem das views aqui:
--    1. Agenda do dia (operacional)
--    2. Paciente completo (cadastro + estatísticas)
--    3. Financeiro mensal (contabilidade)
--    4. Produção por dentista (RH/comissões)
--    5. Estoque crítico (gestão de materiais)
--    6. Odontograma (clínico)
--    7. Parcelas vencidas (cobrança)
--    8. Aniversariantes (relacionamento)
--    9. Retornos pendentes (fidelização)
--   10. Convênios resumo (faturamento)
-- =============================================================================


-- =============================================================================
--  VW_AGENDA_DIA
--
--  Essa é a view que a tela principal da clínica usa. Ela junta consulta,
--  paciente, dentista, sala e procedimento numa visão só.
--
--  Deixei ela sem filtro de data — a aplicação passa a data que quer:
--    SELECT * FROM vw_agenda_dia WHERE DATE(data_hora_inicio) = CURRENT_DATE
--  Isso deixa a view reutilizável pra qualquer data.
-- =============================================================================

CREATE OR REPLACE VIEW vw_agenda_dia AS
SELECT
    c.id                                        AS consulta_id,
    c.data_hora_inicio,
    c.data_hora_fim,
    c.duracao_minutos,
    c.status,
    c.prioridade,

    -- Dados do paciente
    p.id                                        AS paciente_id,
    p.nome_completo                             AS paciente_nome,
    p.data_nascimento,
    DATE_PART('year', AGE(p.data_nascimento))   AS paciente_idade,

    -- Subquery pra pegar só o telefone principal — eficiente com índice em (paciente_id, principal)
    (SELECT pt.numero FROM paciente_telefones pt
     WHERE pt.paciente_id = p.id AND pt.principal = TRUE
     LIMIT 1)                                   AS paciente_telefone,

    -- Dados do dentista — COALESCE pra lidar com dentistas autônomos (sem funcionario_id)
    d.id                                        AS dentista_id,
    COALESCE(f.nome_completo, d.nome_completo)  AS dentista_nome,
    d.cor_agenda,

    s.nome                                      AS sala_nome,
    pr.nome                                     AS procedimento_nome,
    pr.duracao_minutos                          AS proc_duracao,

    c.valor_cobrado,
    cv.nome                                     AS convenio_nome,
    c.chegou_em,
    c.iniciou_em,
    c.observacoes
FROM consultas c
JOIN pacientes      p  ON p.id  = c.paciente_id
JOIN dentistas      d  ON d.id  = c.dentista_id
LEFT JOIN funcionarios f  ON f.id  = d.funcionario_id   -- LEFT porque dentista pode ser autônomo
LEFT JOIN salas        s  ON s.id  = c.sala_id
LEFT JOIN procedimentos pr ON pr.id = c.procedimento_id
LEFT JOIN convenios    cv  ON cv.id = c.convenio_id;


-- =============================================================================
--  VW_PACIENTE_COMPLETO
--
--  Consolida tudo sobre um paciente em uma linha. Útil pra tela de cadastro
--  e pra integrações com outros sistemas.
--
--  As subqueries de estatísticas (total_consultas, faltas, saldo_devedor)
--  tornam essa view um pouco mais pesada. Pra uso frequente, considere
--  transformar em MATERIALIZED VIEW e atualizar diariamente.
-- =============================================================================

CREATE OR REPLACE VIEW vw_paciente_completo AS
SELECT
    p.id,
    p.nome_completo,
    p.cpf,
    p.data_nascimento,
    DATE_PART('year', AGE(p.data_nascimento)) AS idade,
    p.sexo,
    p.email,
    p.bairro,
    p.cidade || ' - ' || p.estado            AS localizacao,

    -- Concatena todos os telefones em uma string — mais fácil de exibir
    (SELECT string_agg(pt.numero, ' / ' ORDER BY pt.principal DESC)
     FROM paciente_telefones pt
     WHERE pt.paciente_id = p.id)            AS telefones,

    cv.nome                                  AS convenio_nome,
    p.numero_carteirinha,
    p.validade_carteirinha,

    pron.id                                  AS prontuario_id,
    pron.numero                              AS prontuario_numero,

    -- Quantas consultas concluídas o paciente tem no histórico
    (SELECT COUNT(*) FROM consultas c
     WHERE c.paciente_id = p.id
       AND c.status = 'CONCLUIDA')           AS total_consultas,

    -- Data da última vez que o paciente foi atendido
    (SELECT MAX(c.data_hora_inicio) FROM consultas c
     WHERE c.paciente_id = p.id
       AND c.status = 'CONCLUIDA')           AS ultima_consulta,

    -- Quantas vezes faltou sem avisar — métrica importante pra gestão de agenda
    (SELECT COUNT(*) FROM consultas c
     WHERE c.paciente_id = p.id
       AND c.status = 'FALTOU')              AS faltas,

    -- Lista de alergias em texto — aparece em destaque na ficha clínica
    (SELECT string_agg(pa.substancia, ', ')
     FROM paciente_alergias pa
     WHERE pa.paciente_id = p.id)            AS alergias,

    -- Quanto o paciente deve no total (parcelas em aberto)
    (SELECT COALESCE(SUM(pg.valor_total - pg.valor_pago), 0)
     FROM pagamentos pg
     WHERE pg.paciente_id = p.id
       AND pg.status IN ('PENDENTE','PARCIAL','ATRASADO')) AS saldo_devedor,

    p.ativo,
    p.criado_em AS cadastrado_em
FROM pacientes p
LEFT JOIN convenios   cv   ON cv.id   = p.convenio_id
LEFT JOIN prontuarios pron ON pron.paciente_id = p.id;


-- =============================================================================
--  VW_FINANCEIRO_MES
--
--  Resumo financeiro agrupado por mês. Usado no dashboard gerencial pra
--  acompanhar receita, descontos e inadimplência ao longo do tempo.
--
--  O truque do FILTER (WHERE ...) é um recurso do PostgreSQL que permite
--  fazer múltiplas agregações condicionais numa query só, sem subqueries.
--  Ex: SUM(...) FILTER (WHERE forma_pagamento = 'PIX') é elegante e eficiente.
-- =============================================================================

CREATE OR REPLACE VIEW vw_financeiro_mes AS
SELECT
    DATE_TRUNC('month', pg.criado_em)        AS mes,
    c.nome_fantasia                          AS clinica,
    COUNT(pg.id)                             AS total_registros,
    COUNT(*) FILTER (WHERE pg.status = 'PAGO') AS registros_pagos,
    SUM(pg.valor_total)                      AS valor_bruto,
    SUM(pg.valor_desconto)                   AS descontos,
    SUM(pg.valor_pago)                       AS valor_recebido,

    -- Quanto ainda está em aberto (receita não realizada)
    SUM(pg.valor_total - pg.valor_pago)
        FILTER (WHERE pg.status IN ('PENDENTE','PARCIAL','ATRASADO')) AS a_receber,

    -- Receita por forma de pagamento — útil pra análise de mix financeiro
    SUM(pg.valor_pago) FILTER (WHERE pg.forma_pagamento = 'PIX')            AS recebido_pix,
    SUM(pg.valor_pago) FILTER (WHERE pg.forma_pagamento = 'DINHEIRO')       AS recebido_dinheiro,
    SUM(pg.valor_pago) FILTER (WHERE pg.forma_pagamento = 'CARTAO_CREDITO') AS recebido_credito,
    SUM(pg.valor_pago) FILTER (WHERE pg.forma_pagamento = 'CARTAO_DEBITO')  AS recebido_debito,
    SUM(pg.valor_pago) FILTER (WHERE pg.forma_pagamento = 'CONVENIO')       AS recebido_convenio
FROM pagamentos pg
JOIN clinica c ON c.id = pg.clinica_id
GROUP BY 1, 2
ORDER BY 1 DESC, 2;


-- =============================================================================
--  VW_PRODUCAO_DENTISTA
--
--  Produção mensal por dentista: consultas realizadas, valor produzido,
--  pacientes atendidos. Serve pra calcular comissões e avaliar performance.
--
--  Incluí canceladas e faltas também pra ter uma visão completa da agenda —
--  um dentista com muitas faltas pode ter um problema de relacionamento
--  com os pacientes ou um perfil de agenda mal gerenciado.
-- =============================================================================

CREATE OR REPLACE VIEW vw_producao_dentista AS
SELECT
    DATE_TRUNC('month', c.data_hora_inicio)         AS mes,
    d.id                                             AS dentista_id,
    COALESCE(f.nome_completo, d.nome_completo)       AS dentista_nome,
    d.cro_numero,
    COUNT(*) FILTER (WHERE c.status = 'CONCLUIDA')  AS consultas_realizadas,
    COUNT(*) FILTER (WHERE c.status = 'FALTOU')     AS faltas,
    COUNT(*) FILTER (WHERE c.status = 'CANCELADA')  AS canceladas,
    SUM(c.valor_cobrado) FILTER (WHERE c.status = 'CONCLUIDA') AS valor_producao,
    AVG(c.duracao_minutos) FILTER (WHERE c.status = 'CONCLUIDA') AS duracao_media_min,
    COUNT(DISTINCT c.paciente_id)                    AS pacientes_atendidos
FROM consultas c
JOIN dentistas   d ON d.id = c.dentista_id
LEFT JOIN funcionarios f ON f.id = d.funcionario_id
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, valor_producao DESC NULLS LAST;


-- =============================================================================
--  VW_ESTOQUE_CRITICO
--
--  Lista todos os materiais que estão abaixo do estoque mínimo.
--  Essa view alimenta os alertas de reposição e é consultada toda manhã
--  pelo gestor de compras.
--
--  A subquery de lote próximo a vencer (30 dias) é um bônus: já avisa se
--  algum material vai vencer em breve, mesmo que ainda tenha quantidade.
-- =============================================================================

CREATE OR REPLACE VIEW vw_estoque_critico AS
SELECT
    m.id,
    m.codigo_interno,
    m.nome,
    cm.nome                             AS categoria,
    m.unidade_medida,
    m.estoque_atual,
    m.estoque_minimo,
    m.ponto_reposicao,
    m.estoque_atual - m.estoque_minimo  AS diferenca,  -- negativo = precisa repor urgente

    f.nome_fantasia                     AS fornecedor_preferido,
    f.telefone                          AS fornecedor_telefone,

    -- Quando foi a última movimentação desse material
    (SELECT me.criado_em FROM movimentos_estoque me
     WHERE me.material_id = m.id
     ORDER BY me.criado_em DESC
     LIMIT 1)                           AS ultimo_movimento,

    -- Existe algum lote vencendo nos próximos 30 dias? Se sim, qual a data?
    (SELECT lm.data_validade FROM lotes_material lm
     WHERE lm.material_id = m.id
       AND lm.data_validade <= CURRENT_DATE + INTERVAL '30 days'
       AND lm.quantidade_atual > 0
     ORDER BY lm.data_validade ASC
     LIMIT 1)                           AS proxima_validade
FROM materiais m
LEFT JOIN categorias_material cm ON cm.id = m.categoria_id
LEFT JOIN fornecedores f         ON f.id  = m.fornecedor_preferido_id
WHERE m.ativo = TRUE
  AND m.estoque_atual <= m.estoque_minimo   -- só os críticos
ORDER BY (m.estoque_atual / NULLIF(m.estoque_minimo, 0)) ASC; -- mais urgentes primeiro


-- =============================================================================
--  VW_ODONTOGRAMA_PACIENTE
--
--  Exibe o odontograma de forma "pivotada" — cada dente numa linha,
--  com o status de cada face em colunas separadas. Facilita a exibição
--  gráfica na interface sem precisar de lógica complexa no front-end.
--
--  O MAX(CASE WHEN ...) é a técnica clássica de pivot em SQL.
--  Funciona porque os valores são mutuamente exclusivos (cada dente tem
--  no máximo uma face de cada tipo).
-- =============================================================================

CREATE OR REPLACE VIEW vw_odontograma_paciente AS
SELECT
    p.id            AS paciente_id,
    p.nome_completo AS paciente_nome,
    pron.id         AS prontuario_id,
    o.numero_dente,
    o.status        AS status_geral,
    o.observacao,

    -- Pivot das faces — uma coluna por face
    MAX(CASE WHEN of2.face = 'VESTIBULAR' THEN of2.status::TEXT END) AS vestibular,
    MAX(CASE WHEN of2.face = 'LINGUAL'    THEN of2.status::TEXT END) AS lingual,
    MAX(CASE WHEN of2.face = 'MESIAL'     THEN of2.status::TEXT END) AS mesial,
    MAX(CASE WHEN of2.face = 'DISTAL'     THEN of2.status::TEXT END) AS distal,
    MAX(CASE WHEN of2.face = 'OCLUSAL'    THEN of2.status::TEXT END) AS oclusal,
    MAX(CASE WHEN of2.face = 'INCISAL'    THEN of2.status::TEXT END) AS incisal,
    o.atualizado_em
FROM odontograma o
JOIN prontuarios  pron ON pron.id = o.prontuario_id
JOIN pacientes    p    ON p.id    = pron.paciente_id
LEFT JOIN odontograma_faces of2 ON of2.odontograma_id = o.id
GROUP BY p.id, p.nome_completo, pron.id, o.numero_dente, o.status, o.observacao, o.atualizado_em
ORDER BY p.nome_completo, o.numero_dente;


-- =============================================================================
--  VW_PARCELAS_VENCIDAS
--
--  Lista de inadimplência: todas as parcelas com vencimento passado que
--  ainda não foram pagas. Ordenada pelas mais antigas primeiro (maior atraso).
--
--  Essa view é a base pro trabalho de cobrança — pode ser usada diretamente
--  pra gerar as notificações de cobrança automáticas.
-- =============================================================================

CREATE OR REPLACE VIEW vw_parcelas_vencidas AS
SELECT
    pa.id                               AS parcela_id,
    p.id                                AS pagamento_id,
    pac.id                              AS paciente_id,
    pac.nome_completo                   AS paciente_nome,
    (SELECT pt.numero FROM paciente_telefones pt
     WHERE pt.paciente_id = pac.id AND pt.principal = TRUE
     LIMIT 1)                           AS telefone,
    pa.numero_parcela,
    pa.valor,
    pa.data_vencimento,
    -- Quantos dias já passou do vencimento
    CURRENT_DATE - pa.data_vencimento   AS dias_atraso,
    pa.status,
    p.descricao                         AS descricao_pagamento
FROM parcelas pa
JOIN pagamentos p   ON p.id   = pa.pagamento_id
JOIN pacientes  pac ON pac.id = p.paciente_id
WHERE pa.status IN ('PENDENTE','ATRASADO')
  AND pa.data_vencimento < CURRENT_DATE
ORDER BY dias_atraso DESC;


-- =============================================================================
--  VW_ANIVERSARIANTES_MES
--
--  Lista pacientes aniversariantes no mês atual. Usada pra enviar
--  mensagens de felicitação e oferecer promoções de birthday — uma
--  estratégia simples de fidelização que gera retorno.
--
--  DATE_PART extrai partes de uma data. DATE_PART('month', data) retorna
--  o número do mês (1-12). Comparamos com o mês atual via CURRENT_DATE.
-- =============================================================================

CREATE OR REPLACE VIEW vw_aniversariantes_mes AS
SELECT
    p.id,
    p.nome_completo,
    p.data_nascimento,
    DATE_PART('year', AGE(p.data_nascimento)) AS idade_atual,
    DATE_PART('day',  p.data_nascimento)      AS dia,
    DATE_PART('month', p.data_nascimento)     AS mes,
    (SELECT pt.numero FROM paciente_telefones pt
     WHERE pt.paciente_id = p.id AND pt.principal = TRUE
     LIMIT 1)                                 AS telefone,
    p.email
FROM pacientes p
WHERE p.ativo = TRUE
  AND p.data_nascimento IS NOT NULL
  AND DATE_PART('month', p.data_nascimento) = DATE_PART('month', CURRENT_DATE)
ORDER BY DATE_PART('day', p.data_nascimento);


-- =============================================================================
--  VW_RETORNOS_PENDENTES
--
--  Pacientes que precisam retornar à clínica mas ainda não agendaram.
--  Alimenta campanhas de reativação — um dos maiores desafios de qualquer
--  clínica é manter os pacientes voltando regularmente.
-- =============================================================================

CREATE OR REPLACE VIEW vw_retornos_pendentes AS
SELECT
    r.id                                        AS retorno_id,
    pac.id                                      AS paciente_id,
    pac.nome_completo                           AS paciente_nome,
    COALESCE(f.nome_completo, d.nome_completo)  AS dentista_nome,
    r.data_sugerida,
    r.prazo_dias,
    r.motivo,
    c.data_hora_inicio                          AS data_consulta_origem,
    (SELECT pt.numero FROM paciente_telefones pt
     WHERE pt.paciente_id = pac.id AND pt.principal = TRUE
     LIMIT 1)                                   AS telefone
FROM retornos r
JOIN consultas  c   ON c.id   = r.consulta_origem_id
JOIN pacientes  pac ON pac.id = r.paciente_id
JOIN dentistas  d   ON d.id   = r.dentista_id
LEFT JOIN funcionarios f ON f.id = d.funcionario_id
WHERE r.agendado = FALSE  -- só os que ainda não retornaram
ORDER BY r.data_sugerida NULLS LAST;


-- =============================================================================
--  VW_CONVENIOS_RESUMO
--
--  Resumo de produção por convênio: quantos pacientes, consultas realizadas
--  e valor gerado. Útil pra avaliar se vale a pena manter credenciamento
--  com determinado convênio.
-- =============================================================================

CREATE OR REPLACE VIEW vw_convenios_resumo AS
SELECT
    cv.id,
    cv.nome,
    COUNT(DISTINCT pac.id)                                       AS total_pacientes,
    COUNT(c.id)                                                  AS total_consultas,
    COUNT(c.id) FILTER (WHERE c.status = 'CONCLUIDA')           AS consultas_realizadas,
    SUM(c.valor_cobrado) FILTER (WHERE c.status = 'CONCLUIDA')  AS valor_produzido
FROM convenios cv
LEFT JOIN pacientes pac ON pac.convenio_id = cv.id
LEFT JOIN consultas c   ON c.convenio_id   = cv.id
WHERE cv.ativo = TRUE
GROUP BY cv.id, cv.nome
ORDER BY total_pacientes DESC;
