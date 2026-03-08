# Hive

Multi-model orchestration plugin for Claude Code. Routes tasks to optimal Claude models running in parallel tmux terminals.

## What it does

- Creates a plan with model-tagged tasks (`[Haiku]`, `[Sonnet]`, `[Opus]`)
- Launches parallel tmux terminals, each running Claude Code with the assigned model
- Each worker gets an isolated git worktree — zero conflicts during execution
- Merges results, runs integration workers when modules need to communicate
- Includes full pipeline: brainstorm, plan, design, execute, validate, security, ship

## Architecture

```
Orchestrator (your Claude Code session)
    │
    ├── /hive-plan → reads CLAUDE.md + roadmap.md, creates model-tagged plan
    │
    ├── /hive-dispatch → for each batch of parallel tasks:
    │   ├── Worker 1 [Haiku]  → tmux pane → git worktree → simple task
    │   ├── Worker 2 [Sonnet] → tmux pane → git worktree → moderate task
    │   └── Worker 3 [Opus]   → tmux pane → git worktree → complex task
    │
    ├── Integration Worker → merges worktrees, connects modules, writes integration tests
    │
    └── /ship → version, changelog, commit, push, PR
```

## Commands

| Command | Description |
|---------|-------------|
| `/hive` | Full pipeline |
| `/hive-plan` | Create model-tagged plan |
| `/hive-dispatch` | Dispatch workers to tmux terminals |
| `/hive-status` | Check worker status |
| `/design-system` | Generate design system |
| `/validate-ux` | Validate UX with Playwright |
| `/security-review` | Security audit |
| `/ship` | Final deploy |

## Model Routing

| Tag | Model | Use case | Cost |
|-----|-------|----------|------|
| `[Haiku]` | claude-haiku-4-5 | Schema, CRUD, boilerplate | ~$0.25/$1.25 per MTok |
| `[Sonnet]` | claude-sonnet-4-6 | Business logic, APIs, tests | ~$3/$15 per MTok |
| `[Opus]` | claude-opus-4-6 | Architecture, security, complex algorithms | ~$15/$75 per MTok |

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `tmux` installed (`brew install tmux` on macOS)
- Git configured

## Installation

```bash
# TODO: publish to marketplace
# claude plugins install hive
```

## How Workers Communicate

Workers use filesystem-based communication (not tmux send-keys):

```
.hive/
├── runs/<run-id>/
│   ├── plan.md              # Full plan (workers read this)
│   ├── context/             # Project context files
│   ├── tasks/
│   │   ├── task-1.assigned.json
│   │   ├── task-1.result.md  # Worker writes: HIVE_TASK_COMPLETE
│   │   └── ...
│   └── status.json
└── worktrees/
    ├── task-1/              # Isolated git worktree
    └── task-2/
```

## License

MIT
