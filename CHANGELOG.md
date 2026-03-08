# Changelog

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
