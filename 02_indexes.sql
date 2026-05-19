-- =============================================================================
--  02_indexes.sql
--  Índices de performance para o banco OdontoRecife
--
--  Índice é uma das ferramentas mais importantes pra performance em banco
--  de dados. A ideia é simples: em vez de o banco varrer a tabela inteira
--  pra encontrar um registro (full table scan), ele usa o índice como um
--  "sumário" pra ir direto onde precisa.
--
--  Analogia: imagine um livro sem índice remissivo. Pra encontrar onde
--  "extração" é mencionado, você leria página por página. Com o índice,
--  você vai direto na página certa.
--
--  Regra geral que aprendi na prática:
--    ✅ Crie índices em colunas de WHERE, JOIN, ORDER BY e GROUP BY frequentes
--    ✅ Índices parciais (com WHERE) são menores e mais rápidos quando você
--       filtra um subconjunto específico de dados
--    ❌ Não crie índice em tudo — cada índice ocupa espaço e torna
--       INSERT/UPDATE/DELETE mais lentos (o índice precisa ser atualizado também)
--
--  Como medir se um índice está sendo usado:
--    EXPLAIN ANALYZE SELECT ... FROM ... WHERE ...
--    Se aparecer "Index Scan", ótimo. Se aparecer "Seq Scan" em tabela grande,
--    talvez precise de um índice.
-- =============================================================================


-- =============================================================================
--  PACIENTES
--
--  Tabela muito consultada. As buscas mais comuns são por nome e CPF.
--  Usei gin_trgm_ops no nome pra suportar busca por substring com ILIKE —
--  por exemplo, buscar "silva" e encontrar "João Silva dos Santos".
-- =============================================================================

-- Índice único parcial no CPF: o WHERE filtra NULLs, então só indexa quem tem CPF
-- (menores às vezes não têm CPF próprio)
CREATE INDEX idx_pacientes_cpf    ON pacientes(cpf) WHERE cpf IS NOT NULL;

-- Índice de trigrama: permite busca por nome com ILIKE '%silva%' de forma eficiente
-- Sem isso, essa busca faz full table scan mesmo com LIKE
CREATE INDEX idx_pacientes_nome   ON pacientes USING gin(nome_completo gin_trgm_ops);

CREATE INDEX idx_pacientes_data_nasc ON pacientes(data_nascimento); -- pra listar aniversariantes
CREATE INDEX idx_pacientes_clinica   ON pacientes(clinica_id);
CREATE INDEX idx_pacientes_convenio  ON pacientes(convenio_id);

-- Índice parcial: só indexa pacientes ativos. Como a maioria é ativa, isso
-- parece não ajudar muito — mas evita que inativos apareçam em buscas rápidas
CREATE INDEX idx_pacientes_ativo  ON pacientes(ativo) WHERE ativo = TRUE;

CREATE INDEX idx_paciente_tel_paciente ON paciente_telefones(paciente_id);
CREATE INDEX idx_paciente_tel_numero   ON paciente_telefones(numero); -- busca por telefone


-- =============================================================================
--  DENTISTAS E FUNCIONÁRIOS
-- =============================================================================

CREATE INDEX idx_dentistas_cro       ON dentistas(cro_numero, cro_estado); -- busca por CRO
CREATE INDEX idx_dentistas_funcionario ON dentistas(funcionario_id);
CREATE INDEX idx_funcionarios_cpf    ON funcionarios(cpf);
CREATE INDEX idx_funcionarios_clinica ON funcionarios(clinica_id);
CREATE INDEX idx_funcionarios_ativo  ON funcionarios(ativo) WHERE ativo = TRUE;
CREATE INDEX idx_dentista_disp_dentista ON dentista_disponibilidade(dentista_id);


-- =============================================================================
--  CONSULTAS
--
--  Essa é a tabela mais acessada do sistema — toda tela de agenda, relatório
--  de produção e faturamento passa por ela. Índices aqui têm impacto direto
--  na velocidade do sistema.
-- =============================================================================

CREATE INDEX idx_consultas_paciente  ON consultas(paciente_id);
CREATE INDEX idx_consultas_dentista  ON consultas(dentista_id);
CREATE INDEX idx_consultas_data      ON consultas(data_hora_inicio); -- base de qualquer filtro de data

-- Índice composto: quando filtramos por clínica E data ao mesmo tempo,
-- o banco usa esse índice em vez de dois separados (muito mais eficiente)
CREATE INDEX idx_consultas_clinica_data  ON consultas(clinica_id, data_hora_inicio);
CREATE INDEX idx_consultas_dentista_data ON consultas(dentista_id, data_hora_inicio);

-- Índice parcial pra consultas ativas (as que mais importam na agenda do dia)
-- Canceladas e concluídas ficam de fora desse índice — ele é pequeno e rápido
CREATE INDEX idx_consultas_pendentes ON consultas(data_hora_inicio)
    WHERE status IN ('AGENDADA','CONFIRMADA');

CREATE INDEX idx_consultas_status ON consultas(status);


-- =============================================================================
--  PRONTUÁRIOS E EVOLUÇÕES
-- =============================================================================

CREATE INDEX idx_prontuarios_paciente  ON prontuarios(paciente_id);
CREATE INDEX idx_prontuarios_numero    ON prontuarios(numero);
CREATE INDEX idx_evolucoes_prontuario  ON evolucoes(prontuario_id);

-- ORDER BY DESC porque a consulta sempre quer ver as últimas evoluções primeiro
CREATE INDEX idx_evolucoes_data        ON evolucoes(data_evolucao DESC);

CREATE INDEX idx_odontograma_prontuario ON odontograma(prontuario_id);
CREATE INDEX idx_odontograma_dente     ON odontograma(numero_dente); -- ex: "quais pacientes têm o #36 cariado?"
CREATE INDEX idx_anamnese_prontuario   ON anamnese(prontuario_id);


-- =============================================================================
--  FINANCEIRO
--
--  Relatórios financeiros geralmente filtram por status (inadimplentes, pagos)
--  e por data de vencimento. Esses índices cobrem os casos mais comuns.
-- =============================================================================

CREATE INDEX idx_pagamentos_paciente  ON pagamentos(paciente_id);
CREATE INDEX idx_pagamentos_status    ON pagamentos(status);
CREATE INDEX idx_pagamentos_clinica   ON pagamentos(clinica_id);

-- Índice parcial pra inadimplência: só indexa pagamentos em aberto com vencimento
-- Perfeito pra query de "quem está devendo?"
CREATE INDEX idx_pagamentos_vencimento ON pagamentos(data_vencimento)
    WHERE status IN ('PENDENTE','PARCIAL','ATRASADO');

CREATE INDEX idx_parcelas_pagamento   ON parcelas(pagamento_id);
CREATE INDEX idx_parcelas_vencimento  ON parcelas(data_vencimento);
CREATE INDEX idx_parcelas_status      ON parcelas(status);

CREATE INDEX idx_comissoes_dentista   ON comissoes(dentista_id);
CREATE INDEX idx_comissoes_competencia ON comissoes(competencia); -- fechamento mensal

-- Índice pra "comissões não pagas por dentista" — consulta do fechamento
CREATE INDEX idx_comissoes_nao_pagas ON comissoes(dentista_id, competencia)
    WHERE pago = FALSE;


-- =============================================================================
--  ESTOQUE
-- =============================================================================

CREATE INDEX idx_materiais_categoria ON materiais(categoria_id);

-- Busca por nome com trigrama — pra achar "luva" mesmo digitando "luvas"
CREATE INDEX idx_materiais_nome      ON materiais USING gin(nome gin_trgm_ops);
CREATE INDEX idx_materiais_codigo    ON materiais(codigo_interno) WHERE codigo_interno IS NOT NULL;

-- Índice parcial especial: lista só materiais abaixo do estoque mínimo
-- Essa query roda frequentemente pra gerar alertas de reposição
CREATE INDEX idx_materiais_estoque_baixo ON materiais(id)
    WHERE estoque_atual <= estoque_minimo AND ativo = TRUE;

CREATE INDEX idx_movimentos_material ON movimentos_estoque(material_id);
CREATE INDEX idx_movimentos_data     ON movimentos_estoque(criado_em DESC);
CREATE INDEX idx_lotes_material      ON lotes_material(material_id);

-- Índice nos lotes com validade: pra identificar materiais próximos do vencimento
CREATE INDEX idx_lotes_validade      ON lotes_material(data_validade)
    WHERE data_validade IS NOT NULL;


-- =============================================================================
--  PLANOS DE TRATAMENTO
-- =============================================================================

CREATE INDEX idx_planos_prontuario   ON planos_tratamento(prontuario_id);
CREATE INDEX idx_planos_dentista     ON planos_tratamento(dentista_id);
CREATE INDEX idx_planos_status       ON planos_tratamento(status);
CREATE INDEX idx_itens_plano_plano   ON itens_plano(plano_id);
CREATE INDEX idx_itens_plano_proc    ON itens_plano(procedimento_id);


-- =============================================================================
--  PROCEDIMENTOS E CONVÊNIOS
-- =============================================================================

CREATE INDEX idx_procedimentos_especialidade ON procedimentos(especialidade_id);
CREATE INDEX idx_procedimentos_nome          ON procedimentos USING gin(nome gin_trgm_ops);
CREATE INDEX idx_procedimentos_tuss          ON procedimentos(codigo_tuss) WHERE codigo_tuss IS NOT NULL;
CREATE INDEX idx_convenio_proc_convenio      ON convenio_procedimentos(convenio_id);
CREATE INDEX idx_convenio_proc_proc          ON convenio_procedimentos(procedimento_id);


-- =============================================================================
--  DOCUMENTOS
-- =============================================================================

CREATE INDEX idx_receitas_prontuario    ON receitas(prontuario_id);
CREATE INDEX idx_atestados_prontuario   ON atestados(prontuario_id);
CREATE INDEX idx_radiografias_prontuario ON radiografias(prontuario_id);
CREATE INDEX idx_documentos_prontuario  ON documentos(prontuario_id);


-- =============================================================================
--  NOTIFICAÇÕES
-- =============================================================================

CREATE INDEX idx_notificacoes_paciente  ON notificacoes(paciente_id);

-- Índice pra encontrar notificações pendentes que precisam ser enviadas agora
-- Esse índice é pequeno (só pendentes) e é consultado o tempo todo pelo worker de envio
CREATE INDEX idx_notificacoes_agendadas ON notificacoes(agendada_para)
    WHERE status = 'PENDENTE';


-- =============================================================================
--  AUDITORIA
--
--  A tabela de auditoria cresce muito. Índices aqui são essenciais pra não
--  travar quando precisar investigar "o que aconteceu com o registro X?"
-- =============================================================================

-- Índice composto por tabela + data: "me mostre as últimas alterações em pagamentos"
CREATE INDEX idx_log_auditoria_tabela  ON log_auditoria(tabela, criado_em DESC);
CREATE INDEX idx_log_auditoria_usuario ON log_auditoria(usuario_id, criado_em DESC);
CREATE INDEX idx_log_auditoria_data    ON log_auditoria(criado_em DESC);
CREATE INDEX idx_log_acesso_usuario    ON log_acesso(usuario_id, criado_em DESC);
CREATE INDEX idx_log_acesso_data       ON log_acesso(criado_em DESC);
