# Hive Bug Report #2 — Script Generation + Invalid CLI Flag

**Data:** 2026-03-08
**Run ID:** 20260308-171121
**Status: ✅ CORRIGIDO** — fix em v1.0.8: substituído `--budget-tokens` por `--max-turns`

---

## Bug 2.1 — `--budget-tokens` não é flag válida do claude CLI

**Onde ocorre:** `hive_write_worker_script` (lib/tmux-manager.sh)

**Sintoma:**
```
error: unknown option '--budget-tokens'
```

O script gerado contém `--budget-tokens <valor>` mas o claude CLI não reconhece essa flag.

**Impacto:** Worker falha imediatamente ao tentar executar.

**Workaround aplicado:** Remover `--budget-tokens` dos scripts gerados manualmente. Usar apenas `--max-turns`.

**Correção sugerida:** Remover `--budget-tokens` de `hive_write_worker_script` ou substituir pela flag correta do claude CLI (verificar `claude --help`).

---

## Bug 2.2 — Caminho relativo no `cd` do worker script

**Onde ocorre:** `hive_write_worker_script` (lib/tmux-manager.sh)

**Sintoma:**
```
task-1.sh: linha 2: cd: .hive/worktrees/task-1: No such file or directory
```

O script gerado usa caminho relativo ao worktree (`cd .hive/worktrees/task-1`) mas o shell do worker está no `$HOME` do usuário, não no root do projeto. O caminho relativo não resolve.

**Impacto:** Worker não consegue entrar no worktree, claude executa no diretório errado.

**Workaround aplicado:** Substituir caminho relativo por absoluto no script:
```bash
cd "/Users/fabiosiqueira/dev/projetos/trading-agent-rl/.hive/worktrees/task-1"
```

**Correção sugerida:** Em `hive_write_worker_script`, usar `$(pwd)` ou `$PROJECT_ROOT` ao gerar o `cd` do script, garantindo caminho absoluto independente de onde o shell do worker inicia.

---

## Impacto Combinado

Os dois bugs juntos impedem qualquer worker de iniciar. O primeiro mata o processo com flag inválida; o segundo causaria execução no diretório errado mesmo que o primeiro fosse corrigido.
