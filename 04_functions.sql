-- =============================================================================
--  04_functions.sql
--  Funções e stored procedures do OdontoRecife
--
--  Mover lógica de negócio pra dentro do banco tem vantagens e desvantagens.
--
--  Vantagens:
--    ✅ A regra vale independente da linguagem da aplicação (Python, Node, etc.)
--    ✅ Operações complexas rodam mais rápido (menos roundtrips de rede)
--    ✅ Transações são mais fáceis de gerenciar
--
--  Desvantagens:
--    ❌ Código SQL é mais difícil de versionar e testar do que código de aplicação
--    ❌ Lógica espalhada em dois lugares pode confundir quem mantém o sistema
--
--  Optei por colocar no banco apenas funções que:
--    1. Trabalham com dados de várias tabelas ao mesmo tempo
--    2. Precisam ser chamadas por triggers
--    3. Fazem cálculos que devem ser consistentes em qualquer contexto
--
--  Todas as funções usam PL/pgSQL, a linguagem procedural nativa do Postgres.
-- =============================================================================


-- =============================================================================
--  fn_gerar_numero_prontuario
--
--  Gera o número único do prontuário no formato "AAAA-NNNNN"
--  Ex: "2025-00001", "2025-00042", "2025-00100"
--
--  Precisei de uma função pra isso porque AUTO_INCREMENT simples não garante
--  a sequência por ano. Em 2026, o contador volta pra 1, não continua de 2025.
--
--  A lógica:
--    1. Pega o ano atual
--    2. Busca o maior número de sequência dos prontuários desse ano e clínica
--    3. Adiciona 1
--    4. Retorna o número formatado
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_gerar_numero_prontuario(p_clinica_id INT)
RETURNS VARCHAR AS $$
DECLARE
    v_ano       CHAR(4) := TO_CHAR(NOW(), 'YYYY');
    v_sequencia INT;
    v_numero    VARCHAR(20);
BEGIN
    -- MAX + COALESCE: se não existir nenhum prontuário nesse ano, retorna 0 (e não NULL)
    SELECT COALESCE(MAX(CAST(SUBSTRING(pron.numero FROM 6) AS INT)), 0) + 1
    INTO v_sequencia
    FROM prontuarios pron
    JOIN pacientes p ON p.id = pron.paciente_id
    WHERE p.clinica_id = p_clinica_id
      AND SUBSTRING(pron.numero FROM 1 FOR 4) = v_ano;

    -- LPAD preenche com zeros à esquerda pra sempre ter 5 dígitos
    v_numero := v_ano || '-' || LPAD(v_sequencia::TEXT, 5, '0');

    RETURN v_numero;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_gerar_numero_orcamento
--
--  Mesma lógica do prontuário, mas pra orçamentos.
--  Formato: "ORC-AAAA-NNNN" → ex: "ORC-2025-0001"
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_gerar_numero_orcamento(p_clinica_id INT)
RETURNS VARCHAR AS $$
DECLARE
    v_prefixo   VARCHAR(10) := 'ORC-' || TO_CHAR(NOW(), 'YYYY');
    v_sequencia INT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero FROM 10) AS INT)), 0) + 1
    INTO v_sequencia
    FROM orcamentos
    WHERE clinica_id = p_clinica_id
      AND SUBSTRING(numero FROM 1 FOR 8) = v_prefixo;

    RETURN v_prefixo || '-' || LPAD(v_sequencia::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_idade_paciente
--
--  Calcula a idade exata de um paciente em anos completos.
--  Parece simples, mas YEAR(data) - YEAR(nascimento) daria errado pra quem
--  ainda não fez aniversário no ano. A função AGE() do Postgres resolve isso.
--
--  Marquei como IMMUTABLE porque pra mesma data de nascimento e mesma
--  data atual sempre retorna o mesmo resultado. Isso permite ao Postgres
--  usar essa função em índices e caches.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_idade_paciente(p_data_nasc DATE)
RETURNS INT AS $$
BEGIN
    RETURN DATE_PART('year', AGE(CURRENT_DATE, p_data_nasc))::INT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- =============================================================================
--  fn_verificar_disponibilidade
--
--  Verifica se um dentista está disponível num determinado horário.
--  Checa dois tipos de conflito:
--    1. Outra consulta já agendada no mesmo período
--    2. Um bloqueio de agenda (férias, reunião, etc.)
--
--  O operador OVERLAPS do PostgreSQL verifica sobreposição de períodos.
--  É muito mais elegante do que escrever a lógica manual:
--    inicio_a < fim_b AND fim_a > inicio_b
--
--  O parâmetro p_consulta_excluir serve pra edições: quando editamos uma
--  consulta existente, não queremos que ela conflite consigo mesma.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_verificar_disponibilidade(
    p_dentista_id       INT,
    p_data_hora_inicio  TIMESTAMPTZ,
    p_data_hora_fim     TIMESTAMPTZ,
    p_consulta_excluir  INT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_conflito INT;
BEGIN
    -- Verifica conflito com outras consultas
    SELECT COUNT(*) INTO v_conflito
    FROM consultas
    WHERE dentista_id = p_dentista_id
      AND id != COALESCE(p_consulta_excluir, -1)   -- ignora a consulta que estamos editando
      AND status NOT IN ('CANCELADA', 'FALTOU')     -- consultas canceladas não bloqueiam
      AND (data_hora_inicio, data_hora_fim) OVERLAPS (p_data_hora_inicio, p_data_hora_fim);

    IF v_conflito > 0 THEN
        RETURN FALSE;  -- já tem consulta nesse horário
    END IF;

    -- Verifica conflito com bloqueios de agenda
    SELECT COUNT(*) INTO v_conflito
    FROM agenda_bloqueio
    WHERE dentista_id = p_dentista_id
      AND (data_hora_inicio, data_hora_fim) OVERLAPS (p_data_hora_inicio, p_data_hora_fim);

    RETURN v_conflito = 0;  -- TRUE = disponível, FALSE = ocupado
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_registrar_movimento_estoque
--
--  Centraliza o registro de qualquer movimentação de estoque.
--  Em vez de fazer INSERT em movimentos_estoque + UPDATE em materiais em
--  dois lugares diferentes, essa função garante que os dois sempre acontecem
--  juntos, na mesma transação.
--
--  O v_mult define se a quantidade vai ser somada ou subtraída do estoque:
--    - ENTRADA e DEVOLUCAO: soma (+1)
--    - SAIDA e VENCIMENTO: subtrai (-1)
--    - AJUSTE: pode ser positivo ou negativo (depende do valor passado)
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_registrar_movimento_estoque(
    p_material_id   INT,
    p_tipo          tipo_movimento_estoque_enum,
    p_quantidade    NUMERIC,
    p_lote_id       INT    DEFAULT NULL,
    p_consulta_id   INT    DEFAULT NULL,
    p_pedido_id     INT    DEFAULT NULL,
    p_motivo        TEXT   DEFAULT NULL,
    p_usuario_id    INT    DEFAULT NULL,
    p_valor_unit    NUMERIC DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_movimento_id INT;
    v_mult         INT;
BEGIN
    -- Define o multiplicador baseado no tipo de movimento
    v_mult := CASE p_tipo
        WHEN 'ENTRADA'    THEN  1
        WHEN 'DEVOLUCAO'  THEN  1
        WHEN 'SAIDA'      THEN -1
        WHEN 'VENCIMENTO' THEN -1
        WHEN 'AJUSTE'     THEN  1  -- ajuste sempre positivo; passe qty negativa se quiser subtrair
        ELSE 1
    END;

    -- Registra o movimento
    INSERT INTO movimentos_estoque (
        material_id, lote_id, tipo, quantidade,
        valor_unitario, valor_total,
        consulta_id, pedido_id, motivo, registrado_por
    ) VALUES (
        p_material_id,
        p_lote_id,
        p_tipo,
        ABS(p_quantidade) * v_mult,
        p_valor_unit,
        CASE WHEN p_valor_unit IS NOT NULL THEN ABS(p_quantidade) * p_valor_unit ELSE NULL END,
        p_consulta_id,
        p_pedido_id,
        p_motivo,
        p_usuario_id
    )
    RETURNING id INTO v_movimento_id;

    -- Atualiza o estoque atual — sempre na mesma transação que o movimento
    UPDATE materiais
    SET estoque_atual = estoque_atual + (ABS(p_quantidade) * v_mult),
        atualizado_em = NOW()
    WHERE id = p_material_id;

    -- Atualiza o lote específico (se informado)
    IF p_lote_id IS NOT NULL THEN
        UPDATE lotes_material
        SET quantidade_atual = quantidade_atual + (ABS(p_quantidade) * v_mult)
        WHERE id = p_lote_id;
    END IF;

    RETURN v_movimento_id;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_recalcular_plano
--
--  Recalcula o valor total de um plano de tratamento somando todos os itens.
--  Chamada automaticamente pelo trigger trg_recalcular_plano sempre que
--  um item do plano é inserido, atualizado ou removido.
--
--  A lógica de desconto: percentual tem prioridade sobre valor fixo.
--  Se o usuário colocar 10% de desconto, o sistema ignora o valor fixo.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_recalcular_plano(p_plano_id INT)
RETURNS VOID AS $$
DECLARE
    v_total    NUMERIC;
    v_desconto NUMERIC;
    v_perc     NUMERIC;
BEGIN
    -- Soma só os itens não cancelados
    SELECT COALESCE(SUM(valor_total), 0)
    INTO v_total
    FROM itens_plano
    WHERE plano_id = p_plano_id
      AND status != 'CANCELADO';

    SELECT desconto_percentual, desconto_valor
    INTO v_perc, v_desconto
    FROM planos_tratamento
    WHERE id = p_plano_id;

    -- Percentual tem prioridade: se tiver percentual, recalcula o valor de desconto
    IF v_perc > 0 THEN
        v_desconto := v_total * (v_perc / 100);
    END IF;

    UPDATE planos_tratamento
    SET valor_total   = v_total,
        valor_final   = v_total - COALESCE(v_desconto, 0),
        atualizado_em = NOW()
    WHERE id = p_plano_id;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_buscar_pacientes
--
--  Função de busca de pacientes com suporte a acentos.
--  Busca por nome (parcial, sem acento), CPF ou telefone.
--
--  O unaccent() remove acentos pra comparação: "jose" encontra "José".
--  Com o índice gin_trgm_ops em nome_completo, mesmo buscas com ILIKE
--  e % são eficientes pra tabelas com milhares de registros.
--
--  Por que retornar TABLE? Porque functions RETURNS TABLE funcionam como
--  uma tabela virtual — você pode fazer SELECT * FROM fn_buscar_pacientes(...).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_buscar_pacientes(
    p_termo      TEXT,
    p_clinica_id INT  DEFAULT NULL,
    p_limite     INT  DEFAULT 20
)
RETURNS TABLE (
    id              INT,
    nome_completo   VARCHAR,
    cpf             CHAR,
    data_nascimento DATE,
    telefone        VARCHAR,
    convenio        VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.nome_completo,
        p.cpf,
        p.data_nascimento,
        (SELECT pt.numero FROM paciente_telefones pt
         WHERE pt.paciente_id = p.id AND pt.principal = TRUE LIMIT 1),
        cv.nome
    FROM pacientes p
    LEFT JOIN convenios cv ON cv.id = p.convenio_id
    WHERE p.ativo = TRUE
      AND (p_clinica_id IS NULL OR p.clinica_id = p_clinica_id)
      AND (
          -- Busca por nome sem acento (o índice gin_trgm acelera isso)
          unaccent(p.nome_completo) ILIKE unaccent('%' || p_termo || '%')

          -- Busca por CPF — remove pontos e traço antes de comparar
          OR p.cpf = REGEXP_REPLACE(p_termo, '[^0-9]', '', 'g')

          -- Busca por telefone — remove formatação
          OR EXISTS (
              SELECT 1 FROM paciente_telefones pt
              WHERE pt.paciente_id = p.id
                AND pt.numero LIKE '%' || REGEXP_REPLACE(p_termo, '[^0-9]', '', 'g') || '%'
          )
      )
    ORDER BY p.nome_completo
    LIMIT p_limite;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_dashboard_dia
--
--  Retorna um resumo do dia da clínica em JSON.
--  Uso: SELECT fn_dashboard_dia(1);
--       SELECT fn_dashboard_dia(1, '2025-06-15');
--
--  Retornar JSONB é interessante porque a API pode passar o objeto direto
--  pro front-end sem transformações — zero overhead de conversão.
--
--  jsonb_build_object('chave', valor, 'chave2', valor2, ...) constrói o JSON.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_dashboard_dia(
    p_clinica_id INT,
    p_data       DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'data',           p_data,
        'agendadas',      COUNT(*) FILTER (WHERE status = 'AGENDADA'),
        'confirmadas',    COUNT(*) FILTER (WHERE status = 'CONFIRMADA'),
        'em_atendimento', COUNT(*) FILTER (WHERE status = 'EM_ATENDIMENTO'),
        'concluidas',     COUNT(*) FILTER (WHERE status = 'CONCLUIDA'),
        'canceladas',     COUNT(*) FILTER (WHERE status = 'CANCELADA'),
        'faltaram',       COUNT(*) FILTER (WHERE status = 'FALTOU'),
        'total',          COUNT(*),
        'receita_dia',    COALESCE(SUM(valor_cobrado) FILTER (WHERE status = 'CONCLUIDA'), 0)
    )
    INTO v_result
    FROM consultas
    WHERE clinica_id = p_clinica_id
      AND DATE(data_hora_inicio) = p_data;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_relatorio_inadimplencia
--
--  Gera o relatório de inadimplência: pacientes com parcelas em atraso,
--  ordenados pelo valor devido (maiores devedores primeiro).
--
--  Uso: SELECT * FROM fn_relatorio_inadimplencia(1);
--       SELECT * FROM fn_relatorio_inadimplencia(1, '2025-06-01');
--
--  O parâmetro p_data_base permite simular a inadimplência em datas passadas,
--  útil pra relatórios históricos e auditoria.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_relatorio_inadimplencia(
    p_clinica_id INT,
    p_data_base  DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    paciente_id         INT,
    paciente_nome       VARCHAR,
    telefone            VARCHAR,
    total_parcelas      BIGINT,
    valor_total_devido  NUMERIC,
    maior_atraso_dias   INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pac.id,
        pac.nome_completo,
        (SELECT pt.numero FROM paciente_telefones pt
         WHERE pt.paciente_id = pac.id AND pt.principal = TRUE LIMIT 1),
        COUNT(pa.id),
        SUM(pa.valor),
        MAX(p_data_base - pa.data_vencimento)::INT
    FROM parcelas pa
    JOIN pagamentos pg  ON pg.id  = pa.pagamento_id
    JOIN pacientes  pac ON pac.id = pg.paciente_id
    WHERE pg.clinica_id = p_clinica_id
      AND pa.status IN ('PENDENTE','ATRASADO')
      AND pa.data_vencimento < p_data_base
    GROUP BY pac.id, pac.nome_completo
    ORDER BY valor_total_devido DESC;
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_calcular_comissao
--
--  Calcula e registra a comissão do dentista quando um pagamento é confirmado.
--  Chamada pelo trigger trg_comissao_pagamento quando status muda pra 'PAGO'.
--
--  O ON CONFLICT DO NOTHING no final evita duplicatas se o trigger rodar
--  mais de uma vez pro mesmo pagamento (ex: alguém atualiza o registro
--  mas o status permanece 'PAGO').
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_calcular_comissao(p_pagamento_id INT)
RETURNS VOID AS $$
DECLARE
    v_rec RECORD;
BEGIN
    -- Busca o pagamento junto com dados do dentista (via consulta)
    SELECT pg.*, c.dentista_id, d.comissao_percentual
    INTO v_rec
    FROM pagamentos pg
    LEFT JOIN consultas c ON c.id = pg.consulta_id
    LEFT JOIN dentistas d ON d.id = c.dentista_id
    WHERE pg.id = p_pagamento_id;

    -- Se não há dentista ou percentual, não há comissão a calcular
    IF v_rec.dentista_id IS NULL OR v_rec.comissao_percentual = 0 THEN
        RETURN;
    END IF;

    INSERT INTO comissoes (
        dentista_id, pagamento_id, consulta_id,
        valor_base, percentual, valor_comissao,
        competencia
    )
    VALUES (
        v_rec.dentista_id,
        p_pagamento_id,
        v_rec.consulta_id,
        v_rec.valor_pago,
        v_rec.comissao_percentual,
        v_rec.valor_pago * (v_rec.comissao_percentual / 100),
        DATE_TRUNC('month', CURRENT_DATE)  -- sempre o primeiro dia do mês
    )
    ON CONFLICT DO NOTHING;  -- evita duplicata se o trigger disparar duas vezes
END;
$$ LANGUAGE plpgsql;


-- =============================================================================
--  fn_atualizar_parcelas_atrasadas
--
--  Atualiza o status de parcelas que passaram do vencimento sem pagamento.
--  Deve ser chamada por um job agendado (cron) toda madrugada.
--
--  Retorna o número de parcelas atualizadas — útil pra log do job.
--
--  Exemplo de uso via psql:
--    SELECT fn_atualizar_parcelas_atrasadas();
--
--  Exemplo de cron no sistema operacional (todo dia às 00:05):
--    5 0 * * * psql -d odonto_recife -c "SELECT fn_atualizar_parcelas_atrasadas();"
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_atualizar_parcelas_atrasadas()
RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    -- Atualiza parcelas individuais
    UPDATE parcelas
    SET status = 'ATRASADO'
    WHERE status = 'PENDENTE'
      AND data_vencimento < CURRENT_DATE;

    GET DIAGNOSTICS v_count = ROW_COUNT;  -- quantas linhas foram afetadas

    -- Propaga o status pro pagamento pai, se tiver parcela atrasada
    UPDATE pagamentos
    SET status = 'ATRASADO'
    WHERE status = 'PENDENTE'
      AND data_vencimento < CURRENT_DATE
      AND id IN (
          SELECT DISTINCT pagamento_id
          FROM parcelas
          WHERE status = 'ATRASADO'
      );

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
