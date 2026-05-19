# 🦷 OdontoRecife — Banco de Dados

Esse projeto nasceu da necessidade de organizar **tudo** que uma clínica odontológica precisa gerenciar: pacientes, consultas, prontuários, financeiro, estoque e muito mais.

Modelei do zero usando **PostgreSQL**, pensando em performance, integridade dos dados e facilidade de manutenção. Se você está estudando modelagem de banco de dados, esse projeto pode ser um bom exemplo de como estruturar algo do mundo real — com as complexidades que ele traz.

---

## 📁 Estrutura dos arquivos

Separei tudo em arquivos com prefixo numérico pra deixar claro a ordem de execução. Cada um tem uma responsabilidade bem definida:

```
odonto-recife-db/
├── README.md              ← você está aqui
├── 01_schema.sql          ← criação de todas as tabelas e tipos
├── 02_indexes.sql         ← índices pra deixar as consultas rápidas
├── 03_views.sql           ← views prontas pra relatórios e dashboards
├── 04_functions.sql       ← funções reutilizáveis (lógica de negócio em SQL)
├── 05_triggers.sql        ← automações que rodam nos bastidores
├── 06_seed_data.sql       ← dados fixos: procedimentos, convênios, especialidades...
└── 07_sample_data.sql     ← dados de exemplo pra testar e desenvolver
```

---

## 🗄️ O que tem no banco?

Dividi em módulos pra ficar mais fácil de entender e evoluir:

| Módulo | Tabelas principais |
|---|---|
| **Clínica** | `clinica`, `salas`, `equipamentos` |
| **Pessoas** | `pacientes`, `dentistas`, `funcionarios` |
| **Agenda** | `consultas`, `agenda_bloqueio`, `lista_espera` |
| **Prontuário** | `prontuarios`, `anamnese`, `odontograma`, `evolucoes` |
| **Tratamento** | `planos_tratamento`, `itens_plano`, `procedimentos` |
| **Financeiro** | `pagamentos`, `parcelas`, `comissoes`, `orcamentos` |
| **Convênios** | `convenios`, `convenio_procedimentos` |
| **Estoque** | `materiais`, `lotes_material`, `movimentos_estoque` |
| **Documentos** | `receitas`, `atestados`, `radiografias` |
| **Auditoria** | `log_auditoria`, `log_acesso` |

---

## 🚀 Como rodar

### Pré-requisitos

- **PostgreSQL 13+** (usei features como colunas geradas e `GENERATED ALWAYS AS`)
- As extensões `uuid-ossp`, `unaccent` e `pg_trgm` (instaladas automaticamente pelo `01_schema.sql`)

### Rodando localmente

```bash
# 1. Crie o banco
createdb odonto_recife

# 2. Execute os scripts na ordem — isso é importante!
psql -d odonto_recife -f 01_schema.sql
psql -d odonto_recife -f 02_indexes.sql
psql -d odonto_recife -f 03_views.sql
psql -d odonto_recife -f 04_functions.sql
psql -d odonto_recife -f 05_triggers.sql
psql -d odonto_recife -f 06_seed_data.sql
psql -d odonto_recife -f 07_sample_data.sql
```

### Com Docker (mais fácil pra testes)

```bash
# Sobe o container
docker run --name odonto-db \
  -e POSTGRES_DB=odonto_recife \
  -e POSTGRES_USER=odonto \
  -e POSTGRES_PASSWORD=senha123 \
  -p 5432:5432 -d postgres:15

# Aguarda uns segundos e executa tudo de uma vez
for f in 0*.sql; do
  psql postgresql://odonto:senha123@localhost/odonto_recife -f "$f"
  echo "✅ $f executado"
done
```

---

## 💡 Decisões de design que tomei

**Por que PostgreSQL?**
Precisava de suporte a JSONB (pra auditoria), tipos customizados (ENUMs), colunas geradas e funções robustas. O Postgres entrega tudo isso nativamente.

**Por que separar dentistas de funcionários?**
Porque nem todo dentista é funcionário CLT — alguns são autônomos. Criei `funcionarios` pra quem tem vínculo empregatício e `dentistas` pra armazenar os dados profissionais (CRO, comissão, cor na agenda). Os dois se relacionam, mas podem existir independentemente.

**Por que o odontograma tem tabela separada por face?**
O odontograma FDI tem 32 dentes × até 5 faces cada. Guardar isso em colunas seria um desastre na manutenção. Separei em `odontograma` (nível do dente) e `odontograma_faces` (nível de cada face), o que dá granularidade total no registro clínico.

**Por que triggers pra criar o prontuário automaticamente?**
Pra garantir que toda vez que um paciente é cadastrado, o prontuário e os 32 dentes já existem no banco — sem depender do código da aplicação. A integridade fica no banco, não no front-end.

**Por que guardar `valor_total` como GENERATED ALWAYS AS?**
Em `itens_plano`, o total é sempre `quantidade × valor_unitario`. Com coluna gerada, o banco garante isso — sem risco de inconsistência entre o que foi salvo e o que deveria ser calculado.

---

## 📊 Alguns números

- ~35 tabelas relacionadas
- 60+ procedimentos com códigos TUSS e CBHPM reais
- Odontograma completo (32 dentes + faces)
- 50 pacientes fictícios com bairros reais de Recife
- Auditoria automática em todas as tabelas críticas

---

## 📍 Contexto

Clínica fictícia localizada em **Recife, Pernambuco — Brasil**. Os bairros, CEPs, DDDs e referências dos dados de exemplo são todos reais.

---

## ⚠️ Aviso

Os dados de pacientes, CPFs e informações pessoais são **completamente fictícios**, gerados apenas para fins de desenvolvimento e estudo. Qualquer semelhança com pessoas reais é mera coincidência.

---

> Feito com muito café e algumas dores de cabeça 🙃
> Sinta-se à vontade pra abrir issues, sugerir melhorias ou fazer fork!
