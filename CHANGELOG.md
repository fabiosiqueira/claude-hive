# Changelog

## [1.0.9] - 2026-03-08

### Added
- `skills/model-routing/SKILL.md`: nova seção "Context Depth Signals" — detecta tarefas que exigem leitura de 3+ módulos interdependentes antes de qualquer implementação; regra: deep-context + Sonnet → upgrade para Opus ou split read/write
- `skills/model-routing/SKILL.md`: Opus Tasks agora inclui explicitamente "context loading across 3+ interdependent modules"
- `skills/model-routing/SKILL.md`: Key Principles agora inclui "Deep context = Opus or split"
- `skills/writing-plans/SKILL.md`: nova seção "When NOT to Use Hive" — documenta anti-padrões (task < 5min, debug com causa raiz desconhecida, single-file change, spike exploratório)

## [1.0.8] - 2026-03-08

### Fixed
- Substituído `--max-budget-usd` por `--max-turns` em toda a stack — `--max-budget-usd` requer billing por API e quebra workers com plano Claude Max (subscription). `--max-turns` funciona em qualquer plano.
- Valores padrão por tier: Haiku=30, Sonnet=80, Opus=150
- Atualizado `lib/tmux-manager.sh` (`hive_write_worker_script`, `hive_build_claude_command`), `skills/dispatching-workers`, `skills/cost-tracking`, `skills/model-routing`, `commands/hive-dispatch.md` e testes

## [1.0.7] - 2026-03-08

### Added
- `hive_print_status` em `lib/tmux-manager.sh`: exibe tabela de status ao vivo lendo `assigned.json`, `result.md` e `progress.txt` por task — independente de `tmux capture-pane` (que não funciona com o Claude CLI)
- Workers instruídos a escrever `task-N.progress.txt` a cada etapa chave (start, testes, implementação, commit) via `agents/worker.md` e template Step 5 de `dispatching-workers/SKILL.md`
- 8 novos testes para `hive_print_status` em `tests/test-tmux-manager.sh`

### Changed
- Step 4c de `hive-dispatch.md`: pseudocódigo inline de `hive_print_status` substituído por chamada à função real da lib; monitor em background atualiza a cada 15s (era 10s inline)

## [1.0.6] - 2026-03-08

### Changed
- `/hive-plan` agora dispara dispatch automaticamente após aprovação do plano — sem necessidade de chamar `/hive-dispatch` manualmente
- `/hive-dispatch` exibe tabela de status em tempo real durante execução: monitor em background atualiza a cada 10s, encerra ao receber todos os signals event-driven

## [1.0.5] - 2026-03-08

### Fixed
- Bug 4.1: `tmux wait-for -S` nunca disparava — `set -e` abortava o script quando claude
  retornava exit code != 0 (budget, timeout, etc), impedindo o signal. Corrigido usando
  `trap 'tmux wait-for -S <channel>' EXIT` que dispara sempre, e removendo `-e` do `set`.

## [1.0.4] - 2026-03-08

### Fixed
- Worktree cleanup agora é step obrigatório e explícito após merge de cada batch — orquestrador deve limpar worktrees e branches imediatamente após merge para evitar estado obsoleto

## [1.0.3] - 2026-03-08

### Fixed
- Bug 3.1: system prompt do worker não exigia commit antes de `HIVE_TASK_COMPLETE` — worktree_merge não capturava o trabalho. Instrução de commit agora explícita no template Step 5 do dispatching-workers skill.

## [1.0.2] - 2026-03-08

### Fixed
- Todas as funções que referenciam windows tmux por nome passam a usar `session:=window_name` (exact match, tmux >= 3.x) — o prefixo `=` evita que o tmux faça prefix-matching e consuma parte do nome do window como extensão do nome da sessão (ex: `hive-20260308-162032:task-6` → `hive-20260308-162032ask-6`)

## [1.0.1] - 2026-03-08

### Fixed
- `hive_launch_worker` falhava em macOS/zsh quando o prompt continha aspas simples, parênteses ou outros metacaracteres de shell — `tmux send-keys` enviava o texto como input interativo e o zsh interpretava os caracteres em tempo real

### Added
- `hive_write_worker_script` — gera um wrapper `.sh` por worker com prompts em arquivos separados; elimina a necessidade de passar prompts inline via `send-keys`
- `hive_launch_worker_script` — envia apenas o caminho do script via `send-keys` (sem metacaracteres)

### Deprecated
- `hive_build_claude_command` — substituído por `hive_write_worker_script + hive_launch_worker_script`; ainda funciona mas é inseguro para prompts com `$`, backticks ou `"`

### Docs
- `skills/dispatching-workers/SKILL.md` Step 4 atualizado para o padrão correto com wrapper scripts

## [1.0.0] - 2026-03-08

### Changed
- Reescrita completa como **Hive** — plugin standalone de orquestração multi-modelo para Claude Code
- Não depende mais do Superpowers ou qualquer outro plugin
- Arquitetura baseada em tmux terminals + git worktrees para isolamento de workers

### Added
- **Orchestration Layer** (`lib/`)
  - `tmux-manager.sh` — operações tmux com suporte a `tmux wait-for` (event-driven)
  - `worktree-manager.sh` — criação/limpeza de git worktrees por worker
  - `plan-parser.sh` — parsing de planos com model tags e batches
  - `result-collector.sh` — coleta de resultados e gestão do run state
- **Model Routing** — tasks roteadas para Haiku (simples), Sonnet (moderado), Opus (complexo)
- **16 Skills** — brainstorming, writing-plans, dispatching-workers, worker-communication, model-routing, integrating-modules, collecting-results, cost-tracking, TDD, debugging, verification, code-review, git-worktrees, finishing-branch, writing-skills, using-hive
- **3 Agents** — worker (execução de tasks), integrator (conexão de módulos), reviewer (code review)
- **8 Commands** — `/hive` (pipeline completo), `/hive-plan`, `/hive-dispatch`, `/hive-status`, `/design-system`, `/validate-ux`, `/security-review`, `/ship`
- **Templates** — worker-prompt, integrator-prompt, plan-header com placeholders `{{VAR}}`
- **Hooks** — session-start injeta using-hive skill context
- **Plugin manifest** — `.claude-plugin/plugin.json` para instalação
- **128 testes unitários** passando (tmux, worktree, plan-parser, result-collector)
- **Event-driven monitoring** — `tmux wait-for` ao invés de polling
- **Integration workers** — conectam módulos pós-batch
- **Roadmap ingestion** — consome `docs/roadmap.md` e transforma em plano Hive

### Removed
- Dependência do framework Superpowers
- Commands locais do Circle v1/v2

## [2.0.0] - 2026-03-08

### Changed
- Reescrita sobre framework Superpowers v4.3.1

### Added
- Pipeline circle, design-system, validate-ux, security-review, ship

### Removed
- Agentes v1 em série, skills como links para repos
