# Changelog

## [3.0.2] - 2026-03-08

### Fixed
- Todas as funções que referenciam windows tmux por nome passam a usar `session:=window_name` (exact match, tmux >= 3.x) — o prefixo `=` evita que o tmux faça prefix-matching e consuma parte do nome do window como extensão do nome da sessão (ex: `hive-20260308-162032:task-6` → `hive-20260308-162032ask-6`)

## [3.0.1] - 2026-03-08

### Fixed
- `hive_launch_worker` falhava em macOS/zsh quando o prompt continha aspas simples, parênteses ou outros metacaracteres de shell — `tmux send-keys` enviava o texto como input interativo e o zsh interpretava os caracteres em tempo real

### Added
- `hive_write_worker_script` — gera um wrapper `.sh` por worker com prompts em arquivos separados; elimina a necessidade de passar prompts inline via `send-keys`
- `hive_launch_worker_script` — envia apenas o caminho do script via `send-keys` (sem metacaracteres)

### Deprecated
- `hive_build_claude_command` — substituído por `hive_write_worker_script + hive_launch_worker_script`; ainda funciona mas é inseguro para prompts com `$`, backticks ou `"`

### Docs
- `skills/dispatching-workers/SKILL.md` Step 4 atualizado para o padrão correto com wrapper scripts

## [3.0.0] - 2026-03-08

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
