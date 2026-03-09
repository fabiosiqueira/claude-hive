---
name: dispatching-workers
description: "Dispatch parallel tmux workers to execute plan batches with model routing and failure recovery"
---

# Dispatching Workers

**Modo silencioso — regra absoluta:**
- O único output de progresso são os labels dos Tasks no footer (via `TaskUpdate activeForm`).
- Não narre passos. Não confirme ações. Não imprima nada entre tool calls.
- Fale APENAS em: ❌ erro, ⚠️ warning, ou relatório de batch (Step 3).

## Setup

```bash
source lib/tmux-manager.sh
source lib/result-collector.sh
source lib/worktree-manager.sh

RUN_ID=$(date +%Y%m%d-%H%M%S)
RUN_DIR=$(hive_init_run "$(pwd)" "$RUN_ID")
cp CLAUDE.md "$RUN_DIR/context/"
# Copie outros arquivos de contexto relevantes (design docs, schemas)
hive_create_session "hive-$RUN_ID"
echo '{"run_id":"'$RUN_ID'","status":"running","current_batch":1}' > "$RUN_DIR/status.json"
```

## Por batch (sequencial entre batches, paralelo dentro do batch)

Para cada batch no plano:

1. Parse tasks do batch via `lib/plan-parser.sh`
2. Criar worktrees + lançar workers (Step 1)
3. Monitorar via TaskCreate/TaskUpdate (Step 2)
4. Imprimir relatório de batch (Step 3)
5. Merge worktrees (Step 4) — **nunca pule o cleanup**
6. Integração, se alguma task tiver `Integration required: yes` (Step 5)
7. Rodar suite de testes completa — deve passar antes do próximo batch
8. Atualizar `status.json` e avançar para o próximo batch

## Step 1: Criar worktrees e lançar workers

```bash
BASE=$(pwd)
for N in $BATCH_TASKS; do
  WT=$(hive_worktree_create "$BASE" "$RUN_ID" "$N")   # 3 args: repo_path, run_id, task_number
  hive_assign_task "$RUN_DIR" "$N" "$MODEL" "$WT"

  SCRIPT="$RUN_DIR/tasks/task-$N.sh"
  hive_write_worker_script "$SCRIPT" "$WT" "$MODEL" "$MAX_TURNS" "$TASK_PROMPT" "$SYS_PROMPT"
  hive_create_worker "hive-$RUN_ID" "task-$N" "$WT"
  hive_launch_worker_script "hive-$RUN_ID" "task-$N" "$SCRIPT"
done
```

- `<model-id>`: `claude-haiku-4-5`, `claude-sonnet-4-6`, `claude-opus-4-6`
- Limites: Haiku=30, Sonnet=80, Opus=150 turns. Use `--max-turns`, nunca `--max-budget-usd`.
- `hive_write_worker_script` salva prompts em arquivos e envia apenas o path via `send-keys` — nunca passe prompts inline.

## Step 2: Monitorar com TaskCreate + TaskUpdate

```
# Criar checklist inicial
Para cada task N:
  id[N] = TaskCreate(subject: "Task N · [Model] desc", activeForm: "Running task N")
  TaskUpdate(id[N], status: "in_progress")

# Loop de polling
Enquanto houver tasks com status não-terminal:
  Para cada task N:
    STATUS = Bash: hive_get_task_status "$RUN_DIR/tasks/task-$N.result.md"
    Se STATUS mudou desde última iteração:
      complete      → TaskUpdate(id[N], completed, subject "Task N · desc — DONE")
      error         → TaskUpdate(id[N], completed, subject "Task N · desc — FAILED")
      context_heavy → TaskUpdate(id[N], completed, subject "Task N · desc — CONTEXT_OVERLOAD")
      running       → TaskUpdate(id[N], activeForm: hive_get_task_progress "$RUN_DIR" N)
  Bash: sleep 10
```

Status terminal = `complete | error | context_heavy`. O arquivo de resultado persiste no filesystem — sem race condition.

## Step 3: Relatório de batch (obrigatório)

Tasks `completed` somem do footer — imprima sempre imediatamente após o loop:

```
## Batch N — resultado
| Task | Modelo | Status | Último progresso |
|------|--------|--------|-----------------|
| Task 1 · Schema migration | claude-haiku-4-5   | ✓ DONE           | Committing |
| Task 2 · Auth service     | claude-sonnet-4-6  | ✗ FAILED         | Build error |
| Task 3 · Caching layer    | claude-opus-4-6    | ⚠ CONTEXT_OVERLOAD | Reading module D |

Tasks com falha: N — requer retry ou escalação
Tasks com context overload: N — requer split
```

Fontes: `hive_get_task_status`, `hive_get_task_progress`, campo `model` do `task-N.assigned.json`.

## Step 4: Merge e cleanup

```bash
for N in $BATCH_TASKS; do
  hive_worktree_merge "$BASE" "$RUN_ID" "$N"
done
hive_worktree_cleanup_run "$BASE" "$RUN_ID"
```

**Conflitos de merge:**
- Conflito trivial (ambos adicionaram arquivos diferentes) → resolva automaticamente
- Conflito não-trivial → despache integration worker com ambas as versões como contexto
- Se integration worker não resolver → marque BLOCKED
- Mesmo em BLOCKED: limpe os worktrees bem-sucedidos; só o bloqueado fica até resolver

**Verificar cleanup:**
```bash
git worktree list         # deve mostrar só o worktree principal
git branch | grep "hive/$RUN_ID"  # deve estar vazio
```

## Step 5: Integração (quando `Integration required: yes`)

1. Todos os worktrees do batch devem estar mergeados primeiro
2. Despache um integration worker com model `[Sonnet]` mínimo
3. O worker recebe todos os integration prompts do batch — conecta módulos, corrige type mismatches, adiciona glue code
4. Rodar testes de integração após o worker concluir
5. Se os testes falharem → re-despachar o integration worker com o output de erro

## Worker Instruction Template

```
TASK: <descrição da task no plano>
WORKTREE: .hive/worktrees/task-<N>/
RESULT FILE: .hive/runs/<run-id>/tasks/task-<N>.result.md
PROGRESS FILE: .hive/runs/<run-id>/tasks/task-<N>.progress.txt

Escreva progresso nos momentos-chave (início, após ler arquivos, após escrever testes, após implementar, antes do commit):
  echo "[$(date +%H:%M:%S)] <o que está fazendo>" >> <progress-file>

REGRAS:
- TDD: escreva o teste antes da implementação; nunca implemente sem teste falhando
- Commit TUDO antes de escrever o result file: git add <files> && git commit -m "hive: task <N> — <desc>"
- Só após commit: echo 'HIVE_TASK_COMPLETE' >> <result-file>
- Em erro irrecuperável: commit o trabalho parcial, depois echo 'HIVE_TASK_ERROR' >> <result-file>
- Se contexto ficar pesado: echo 'HIVE_TASK_CONTEXT_HEAVY' >> <result-file>
- Não modifique arquivos fora do seu worktree
- Não se comunique com outros workers
```

## Failure Recovery

```
1ª falha  → retry com mesmo modelo (worktree limpa, novo launch)
2ª falha  → escalar: Haiku→Sonnet, Sonnet→Opus, Opus→BLOCKED
BLOCKED   → halt batch; decidir: skip (sem dependentes), abortar run, ou pedir intervenção
```

## Princípios

- **Um worker por task, um worktree por worker.** Sem estado mutável compartilhado.
- **Batches são atômicos.** Todas as tasks do batch devem completar antes do próximo começar.
- **Retry antes de escalar, escalar antes de bloquear.**
- **Testes gateiam batch transitions.** Suite completa deve passar após merge.
- **O plano é o contrato.** Workers executam exatamente o que o plano especifica.

## Gotchas críticos

**1. Nunca passe prompt inline via `tmux send-keys`** — metacaracteres (`'`, `)`, `$`, backticks) quebram. Use sempre `hive_write_worker_script` + `hive_launch_worker_script`.

**2. Exact match em window names** — sessões com hífens causam prefix-match no tmux. As funções de `lib/tmux-manager.sh` já usam `:=window_name`. Em operações manuais: `-t "session:=window"`.

**3. `--max-budget-usd` e `--budget-tokens` quebram com Claude Max** — use `--max-turns`. `hive_write_worker_script` já gera o script correto.

**4. `hive_worktree_create` recebe 3 args** — `repo_path, run_id, task_number`. Passar 2 cria worktree em path errado.

**5. `signal_channel` removido (v1.1.0)** — `hive_write_worker_script` aceita 6 args (sem 7º). Monitoring via `hive_get_task_status` + TaskUpdate, não `tmux wait-for`.
