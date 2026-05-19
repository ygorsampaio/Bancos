-- =============================================================================
--  05_triggers.sql
--  Triggers de automação e auditoria
--
--  Trigger é uma função que o banco executa automaticamente quando algo
--  acontece numa tabela (INSERT, UPDATE, DELETE). É o mecanismo mais
--  poderoso de automação dentro do banco de dados.
--
--  Anatomia de um trigger no Postgres:
--    1. Você cria a FUNCTION que contém a lógica (retorna TRIGGER)
--    2. Você cria o TRIGGER que conecta a função a uma tabela e evento
--
--  Timing importa:
--    - BEFORE: roda antes da operação. Pode modificar os dados (NEW) ou cancelar.
--    - AFTER: roda depois. Os dados já foram salvos. Boa pra auditoria.
--
--  Dentro da função trigger, duas variáveis especiais:
--    - NEW: o registro novo (disponível em INSERT e UPDATE)
--    - OLD: o registro antes da mudança (disponível em UPDATE e DELETE)
--    - TG_OP: a operação ('INSERT', 'UPDATE', 'DELETE')
--    - TG_TABLE_NAME: nome da tabela que disparou o trigger
-- =============================================================================


-- =============================================================================
--  AUDITORIA GENÉRICA
--
--  Essa é a abordagem que mais gosto: uma única função de auditoria que
--  funciona pra qualquer tabela. Você cria o trigger em cada tabela que
--  quer auditar, e todos apontam pra mesma função.
--
--  Guardo os dados em JSONB — to_jsonb(NEW) converte o registro inteiro
--  pra JSON automaticamente, sem precisar listar as colunas. Isso significa
--  que se você adicionar uma coluna na tabela, ela automaticamente aparece
--  no log de auditoria.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Novo registro: guarda só o NEW (não tem OLD)
        INSERT INTO log_auditoria(tabela, operacao, registro_id, dados_novos)
        VALUES (TG_TABLE_NAME, 'I', NEW.id, to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Alteração: guarda antes e depois — permite ver exatamente o que mudou
        INSERT INTO log_auditoria(tabela, operacao, registro_id, dados_antigos, dados_novos)
        VALUES (TG_TABLE_NAME, 'U', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        -- Deleção: guarda o OLD (NEW não existe mais)
        INSERT INTO log_auditoria(tabela, operacao, registro_id, dados_antigos)
        VALUES (TG_TABLE_NAME, 'D', OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Aplica o trigger de auditoria em todas as tabelas críticas de uma vez
-- usando um loop dinâmico — muito mais elegante do que criar 15 triggers manualmente
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'pacientes', 'consultas', 'pagamentos', 'parcelas',
        'planos_tratamento', 'itens_plano', 'prontuarios',
        'anamnese', 'evolucoes', 'receitas', 'atestados',
        'dentistas', 'funcionarios', 'materiais', 'convenios'
    ]
    LOOP
        -- EXECUTE com format() permite SQL dinâmico — %I escapa o identificador corretamente
        EXECUTE format(
            'CREATE TRIGGER trg_audit_%I
             AFTER INSERT OR UPDATE OR DELETE ON %I
             FOR EACH ROW EXECUTE FUNCTION fn_trigger_auditoria()',
            t, t
        );
    END LOOP;
END $$;


-- =============================================================================
--  ATUALIZAR CAMPO "atualizado_em" AUTOMATICAMENTE
--
--  Toda vez que um registro é alterado, o campo atualizado_em deve refletir
--  o momento da última mudança. Em vez de depender do código da aplicação
--  fazer isso, o trigger garante que sempre acontece.
--
--  Uso o mesmo padrão do trigger de auditoria: uma função, vários triggers.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_set_atualizado_em()
RETURNS TRIGGER AS $$
BEGIN
    -- NEW.atualizado_em é o campo que estamos atualizando
    -- NOW() retorna o timestamp com timezone do momento exato
    NEW.atualizado_em := NOW();
    RETURN NEW;  -- precisamos retornar NEW no BEFORE trigger pra salvar a mudança
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'pacientes', 'consultas', 'pagamentos', 'planos_tratamento',
        'prontuarios', 'materiais', 'procedimentos', 'funcionarios', 'dentistas'
    ]
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_set_atualizado_%I
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em()',
            t, t
        );
    END LOOP;
END $$;


-- =============================================================================
--  CRIAR PRONTUÁRIO E ODONTOGRAMA AUTOMATICAMENTE
--
--  Esse foi o trigger que mais me deu trabalho de pensar. O problema:
--  toda vez que um paciente é cadastrado, precisa criar o prontuário
--  e os 32 dentes do odontograma. Se isso ficasse no código da aplicação,
--  qualquer bug ou chamada direta ao banco quebraria a integridade.
--
--  Solução: trigger AFTER INSERT em pacientes. Roda depois que o paciente
--  foi salvo (e tem ID disponível), cria o prontuário com número gerado
--  pela função fn_gerar_numero_prontuario(), e inicializa os 32 dentes
--  como HÍGIDO (saudável).
--
--  O UNNEST(ARRAY[...]) é uma forma elegante de gerar múltiplas linhas
--  a partir de um array — perfeito pra inserir os 32 dentes de uma vez.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_criar_prontuario()
RETURNS TRIGGER AS $$
DECLARE
    v_numero       VARCHAR(20);
    v_prontuario_id INT;
BEGIN
    -- Gera o número do prontuário usando a função do 04_functions.sql
    v_numero := fn_gerar_numero_prontuario(NEW.clinica_id);

    -- Cria o prontuário e captura o ID gerado
    INSERT INTO prontuarios (paciente_id, numero, data_abertura)
    VALUES (NEW.id, v_numero, CURRENT_DATE)
    RETURNING id INTO v_prontuario_id;

    -- Inicializa o odontograma com todos os 32 dentes permanentes (notação FDI)
    -- Quadrante 1: dentes superiores direitos (11-18)
    -- Quadrante 2: dentes superiores esquerdos (21-28)
    -- Quadrante 3: dentes inferiores esquerdos (31-38)
    -- Quadrante 4: dentes inferiores direitos (41-48)
    INSERT INTO odontograma (prontuario_id, numero_dente, status)
    SELECT
        v_prontuario_id,
        t.dente,
        'HÍGIDO'
    FROM UNNEST(ARRAY[
        11, 12, 13, 14, 15, 16, 17, 18,
        21, 22, 23, 24, 25, 26, 27, 28,
        31, 32, 33, 34, 35, 36, 37, 38,
        41, 42, 43, 44, 45, 46, 47, 48
    ]) AS t(dente);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_criar_prontuario
    AFTER INSERT ON pacientes
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_criar_prontuario();


-- =============================================================================
--  RECALCULAR TOTAL DO PLANO AO ALTERAR ITENS
--
--  Sempre que um item do plano de tratamento é adicionado, editado ou
--  removido, o valor total do plano precisa ser recalculado.
--
--  Em vez de fazer isso no código, esse trigger chama fn_recalcular_plano()
--  automaticamente. O dentista pode editar os itens direto no banco
--  que os totais continuarão corretos.
--
--  Note o COALESCE(NEW, OLD): em DELETE, NEW é NULL; em INSERT, OLD é NULL.
--  Pra retornar o registro certo, usamos COALESCE.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_recalcular_plano()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_recalcular_plano(OLD.plano_id);  -- PERFORM descarta o resultado da função
    ELSE
        PERFORM fn_recalcular_plano(NEW.plano_id);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalcular_plano
    AFTER INSERT OR UPDATE OR DELETE ON itens_plano
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_recalcular_plano();


-- =============================================================================
--  VALIDAR CONFLITO DE AGENDA
--
--  Esse trigger BEFORE (antes de salvar) verifica se o dentista já tem
--  outra consulta ou bloqueio no horário escolhido.
--
--  Se houver conflito, lança uma exceção com RAISE EXCEPTION — o banco
--  desfaz a operação e retorna o erro pra aplicação tratar.
--
--  Por que BEFORE e não AFTER? Porque no BEFORE podemos cancelar a operação.
--  No AFTER os dados já foram salvos e seria necessário desfazer manualmente.
--
--  O ERRCODE P0001 é o código genérico pra exceções customizadas no Postgres.
--  A aplicação pode capturar esse código pra exibir a mensagem de erro certa.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_validar_agenda()
RETURNS TRIGGER AS $$
BEGIN
    -- Consultas canceladas/faltou não precisam validar disponibilidade
    IF NEW.status NOT IN ('CANCELADA', 'FALTOU', 'REMARCADA') THEN

        IF NOT fn_verificar_disponibilidade(
            NEW.dentista_id,
            NEW.data_hora_inicio,
            -- Se data_hora_fim não foi informada, calcula com base na duração
            COALESCE(
                NEW.data_hora_fim,
                NEW.data_hora_inicio + (NEW.duracao_minutos * INTERVAL '1 minute')
            ),
            -- Em UPDATE, passa o ID da consulta atual pra não conflitar consigo mesma
            CASE WHEN TG_OP = 'UPDATE' THEN OLD.id ELSE NULL END
        ) THEN
            RAISE EXCEPTION 'Conflito de agenda: o dentista já possui atendimento neste horário.'
                USING ERRCODE = 'P0001';
        END IF;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_agenda
    BEFORE INSERT OR UPDATE ON consultas
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_validar_agenda();


-- =============================================================================
--  GERAR NÚMERO DE RECIBO AUTOMATICAMENTE
--
--  O número do recibo é gerado depois que o pagamento é inserido
--  (precisamos do ID pra compor o número).
--
--  Formato: REC-AAAAMM-000001
--  Exemplo: REC-202506-000042
--
--  Por isso é BEFORE INSERT: antes de salvar, populamos o campo.
--  Na hora do INSERT, o banco ainda não gerou o ID automático (SERIAL),
--  mas nesse caso o ID já existe porque estamos no BEFORE — a sequência
--  já foi consumida mesmo que a transação ainda não tenha sido confirmada.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_numero_recibo()
RETURNS TRIGGER AS $$
BEGIN
    -- Só gera se não foi informado manualmente
    IF NEW.numero_recibo IS NULL THEN
        NEW.numero_recibo := 'REC-'
                          || TO_CHAR(NOW(), 'YYYYMM')
                          || '-'
                          || LPAD(NEW.id::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_numero_recibo
    BEFORE INSERT ON pagamentos
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_numero_recibo();


-- =============================================================================
--  CALCULAR COMISSÃO AO CONFIRMAR PAGAMENTO
--
--  Quando o status de um pagamento muda pra 'PAGO', calculamos e
--  registramos automaticamente a comissão do dentista.
--
--  A condição (OLD.status IS NULL OR OLD.status != 'PAGO') garante que
--  a comissão só é calculada uma vez — quando o status muda pra PAGO
--  pela primeira vez. Se o registro já estava PAGO e foi editado por
--  outro motivo, não duplica a comissão.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_comissao_pagamento()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'PAGO'
       AND (OLD IS NULL OR OLD.status IS DISTINCT FROM 'PAGO') THEN
        PERFORM fn_calcular_comissao(NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comissao_pagamento
    AFTER INSERT OR UPDATE ON pagamentos
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_comissao_pagamento();


-- =============================================================================
--  REGISTRAR DATA DO PRIMEIRO ATENDIMENTO
--
--  Quando uma consulta é concluída, verificamos se o paciente tem
--  primeiro_atendimento preenchido. Se não tem, preenchemos agora.
--
--  Isso serve pra saber há quanto tempo o paciente é cliente da clínica,
--  útil pra campanhas de aniversário de relacionamento.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_primeiro_atendimento()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'CONCLUIDA' THEN
        -- UPDATE condicional: só atualiza se o campo ainda está NULL
        UPDATE pacientes
        SET primeiro_atendimento = DATE(NEW.data_hora_inicio)
        WHERE id = NEW.paciente_id
          AND primeiro_atendimento IS NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_primeiro_atendimento
    AFTER INSERT OR UPDATE ON consultas
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_primeiro_atendimento();


-- =============================================================================
--  ALERTA DE ESTOQUE MÍNIMO
--
--  Quando o estoque de um material cai abaixo do mínimo pela primeira vez
--  (antes estava acima, agora está abaixo), emite um alerta via RAISE NOTICE.
--
--  O RAISE NOTICE não cancela a operação — só envia uma mensagem pro cliente
--  (psql, aplicação). Numa integração real, aqui você chamaria uma função
--  que envia email/Slack/push notification pro responsável por compras.
--
--  Por que comparar OLD > mínimo E NEW <= mínimo?
--  Porque queremos o momento exato em que cruzou o limite, não toda vez
--  que já está abaixo (o que dispararia o alerta em cada saída de estoque).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_trigger_alerta_estoque()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estoque_atual <= NEW.estoque_minimo
       AND OLD.estoque_atual > OLD.estoque_minimo THEN
        RAISE NOTICE
            'ALERTA DE ESTOQUE: "%" atingiu o nível mínimo! Atual: % % | Mínimo: % %',
            NEW.nome,
            NEW.estoque_atual,
            NEW.unidade_medida,
            NEW.estoque_minimo,
            NEW.unidade_medida;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alerta_estoque
    AFTER UPDATE ON materiais
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_alerta_estoque();
