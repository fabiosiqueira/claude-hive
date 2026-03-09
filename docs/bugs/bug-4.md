# Hive Bug Report #4 — tmux wait-for signal nunca dispara

**Data:** 2026-03-08
**Run ID:** 20260308-175911
**Status: ✅ CORRIGIDO** — fix em v1.1.0: migração de `tmux wait-for` para file polling eliminou o problema do `set -e`

---

## Bug 4.1 — `set -euo pipefail` mata o script antes de `tmux wait-for -S`

**Onde ocorre:** Script gerado por `hive_write_worker_script` (lib/tmux-manager.sh)

**Sintoma:**
Workers completam a tarefa com sucesso (result file contém `HIVE_TASK_COMPLETE`),
mas o `hive_wait_for_all_workers` no orchestrator nunca desbloqueia. O orchestrador
fica travado indefinidamente esperando por signals que nunca chegam.

**Causa provável:**
O script gerado por `hive_write_worker_script` começa com `set -euo pipefail`.
O `claude` CLI pode retornar exit code != 0 mesmo em execuções bem-sucedidas
(ex: budget atingido, timeout, ou simplesmente exit code diferente de 0 ao
encerrar normalmente). Com `set -e`, qualquer exit code != 0 aborta o script
imediatamente — o `tmux wait-for -S <channel>` na última linha nunca executa.

**Script gerado:**
```bash
#!/usr/bin/env bash
set -euo pipefail           # <-- se claude retorna exit != 0, script morre aqui
cd /path/to/worktree

_task_prompt=$(cat task-prompt.txt)
_system_prompt=$(cat system-prompt.txt)

claude --model ... --dangerously-skip-permissions \
  --append-system-prompt "$_system_prompt" \
  --max-budget-usd 2.00 \
  -p "$_task_prompt"
                             # <-- claude retorna exit != 0
tmux wait-for -S channel    # <-- NUNCA EXECUTA
```

**Impacto:**
O mecanismo event-driven (`hive_wait_for_all_workers`) fica permanentemente bloqueado.
O orchestrador não sabe que os workers já terminaram. O usuário vê 10+ minutos
sem progresso e precisa intervir manualmente.

**Workaround aplicado:**
Verificar result files manualmente com `grep HIVE_TASK_COMPLETE` e parar o `wait-for`.

**Correção sugerida:**
No `hive_write_worker_script`, gerar o script de forma que o `tmux wait-for -S`
execute SEMPRE, independente do exit code do claude:

```bash
#!/usr/bin/env bash
set -uo pipefail  # sem -e

cd /path/to/worktree
# ... prompts ...

claude --model ... -p "$_task_prompt" || true   # captura exit code sem abortar

tmux wait-for -S channel   # SEMPRE executa
```

Ou alternativamente, usar trap:
```bash
set -euo pipefail
trap 'tmux wait-for -S channel' EXIT   # signal dispara mesmo em erro

claude --model ... -p "$_task_prompt"
```

---

## Impacto

Este bug anula completamente o mecanismo event-driven do Hive. Na prática,
`hive_wait_for_all_workers` nunca funciona, forçando o orchestrador a cair
no anti-padrão de polling manual — exatamente o que a lib foi criada para evitar.
