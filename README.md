# Hive

Hive is a multi-model orchestration plugin for Claude Code. It routes tasks to parallel tmux workers, each running Claude Code with the optimal model for the job — cutting costs while keeping quality high on the tasks that matter.

## How it works

When you trigger `/hive`, it doesn't just start coding. It reads your project context, refines requirements through dialogue, then generates a plan where every task is tagged with the right model tier (`[Haiku]`, `[Sonnet]`, or `[Opus]`).

Once you approve the plan, Hive launches parallel tmux terminals — one per task batch — each worker running in an isolated git worktree. Workers communicate through the filesystem, results are collected, and an integration worker connects independently-built modules. Then it ships.

The key insight: not every task needs Opus. Schema migrations, CRUD, and boilerplate run on Haiku at ~60x lower cost. Complex architecture and security reviews get Opus. Everything else gets Sonnet.

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace first:

```bash
/plugin marketplace add fabiosiqueira/claude-hive
```

Then install the plugin:

```bash
/plugin install hive@claude-hive
```

### Verify Installation

Start a new session and run `/hive`. The agent should walk you through the pipeline.

## The Pipeline

```
/hive
  │
  ├── brainstorm     → refine requirements through dialogue
  ├── /hive-plan     → create model-tagged plan with dependency graph
  ├── /hive-dispatch → launch parallel tmux workers in isolated worktrees
  ├── integration    → merge worktrees, connect modules, run integration tests
  ├── review         → code review + security audit
  └── /ship          → version, changelog, commit, push, PR
```

## Commands

| Command | Description |
|---------|-------------|
| `/hive` | Full pipeline |
| `/hive-plan` | Create model-tagged implementation plan |
| `/hive-dispatch` | Dispatch workers to tmux terminals |
| `/hive-status` | Check worker status |
| `/design-system` | Generate design system |
| `/validate-ux` | Validate UX with Playwright |
| `/security-review` | Security audit |
| `/ship` | Version, changelog, commit, push, PR |

## Model Routing

| Tag | Model | Best for | Cost |
|-----|-------|----------|------|
| `[Haiku]` | claude-haiku-4-5 | Schema, CRUD, boilerplate | ~$0.25/$1.25 per MTok |
| `[Sonnet]` | claude-sonnet-4-6 | Business logic, APIs, tests | ~$3/$15 per MTok |
| `[Opus]` | claude-opus-4-6 | Architecture, security, complex algorithms | ~$15/$75 per MTok |

## Skills Library

**Orchestration**
- **using-hive** — pipeline overview and entry point
- **writing-plans** — model-tagged plans with dependency graphs
- **dispatching-workers** — parallel tmux worker management
- **worker-communication** — filesystem-based coordination protocol
- **collecting-results** — aggregate results, detect conflicts
- **integrating-modules** — connect independently-built modules
- **model-routing** — heuristics for choosing the right model tier
- **cost-tracking** — estimate and track spend across workers

**Process**
- **brainstorming** — refine requirements before implementation
- **test-driven-development** — RED-GREEN-REFACTOR cycle
- **systematic-debugging** — root cause before proposing fixes
- **verification** — confirm work is actually done before declaring done
- **code-review** — structured evaluation with severity levels
- **git-worktrees** — isolated worktrees per worker
- **finishing-branch** — merge, PR, or push decision workflow
- **writing-skills** — create new Hive skills

## Worker Isolation

Each worker gets an isolated git worktree under `.hive/worktrees/task-N/`. Workers never touch each other's files. Communication happens through:

```
.hive/runs/<run-id>/
├── plan.md                    # Full plan (read by all workers)
├── tasks/
│   ├── task-1.assigned.json   # Task assignment
│   ├── task-1.result.md       # Worker output (HIVE_TASK_COMPLETE / HIVE_TASK_ERROR)
│   └── task-1.progress.txt    # Live progress log
└── status.json
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `tmux` (`brew install tmux` on macOS)
- Git configured

## Updating

```bash
/plugin update hive
```

## Contributing

Skills live in `skills/<name>/SKILL.md`. To contribute:

1. Fork the repository
2. Create a branch for your skill or fix
3. Follow the `writing-skills` skill for creating new skills
4. Submit a PR

## License

MIT License — see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: https://github.com/fabiosiqueira/claude-hive/issues
