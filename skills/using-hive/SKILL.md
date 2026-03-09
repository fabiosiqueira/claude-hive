---
name: using-hive
description: "Intro skill — what Hive is, available commands, model routing, and pipeline overview"
---

# Using Hive

## Overview

Hive is a multi-model orchestration plugin for Claude Code. It dispatches parallel workers — each running Claude Code with a different model — coordinated through tmux sessions and git worktrees. The orchestrator reads a structured plan, routes each task to the optimal model by complexity, and merges results back into the main branch.

This skill is loaded on session start. It provides orientation for every Hive session.

## Available Commands

| Command | Purpose |
|---------|---------|
| `/hive` | Full pipeline: brainstorm → plan → design → execute → validate → security → ship |
| `/hive-plan` | Create a structured implementation plan with model tags and dependency graph |
| `/hive-dispatch` | Dispatch tmux workers to execute a plan in parallel batches |
| `/hive-status` | Check current run status — worker progress, blocked tasks, batch completion |
| `/hive-cleanup` | Kill all active workers and tmux sessions — use when a run is interrupted or workers go orphan |
| `/design-system` | Generate design system spec with tokens, components, and layouts |
| `/validate-ux` | Run Playwright-based UX tests against implemented UI |
| `/security-review` | OWASP-focused security audit of the codebase |
| `/ship` | Final deploy: version bump, changelog, commit, push, PR |

## Model Routing

Hive routes tasks to three model tiers based on complexity:

| Tag | Model | Assigned To |
|-----|-------|-------------|
| `[Haiku]` | claude-haiku-4-5 | Schema definitions, CRUD operations, boilerplate, file renames, simple config |
| `[Sonnet]` | claude-sonnet-4-6 | Business logic, API endpoints, test suites, data transformations, integrations |
| `[Opus]` | claude-opus-4-6 | Architecture decisions, security-critical code, complex algorithms, system design |

### Escalation

When a worker fails at its assigned model tier, Hive escalates:

1. Retry with same model (once)
2. Escalate: Haiku → Sonnet → Opus
3. If Opus fails: mark task as `BLOCKED`, halt batch, alert orchestrator

## Worker Isolation

Each worker operates in a dedicated git worktree:

- Worktrees live in `.hive/worktrees/task-<N>/`
- Workers are launched via `claude --model <model> --dangerously-skip-permissions`
- A worker must NOT modify files outside its own worktree
- After completion, workers write a result file to `.hive/runs/<run-id>/tasks/`

## Filesystem-Based Communication

Workers do not communicate through tmux send-keys or stdin. All coordination happens through the filesystem:

- **Plan**: `.hive/runs/<run-id>/plan.md` — the full execution plan
- **Context**: `.hive/runs/<run-id>/context/` — shared project context files
- **Tasks**: `.hive/runs/<run-id>/tasks/task-<N>.assigned.json` — assignment metadata
- **Results**: `.hive/runs/<run-id>/tasks/task-<N>.result.md` — completion output with markers
- **Status**: `.hive/runs/<run-id>/status.json` — aggregated run state

The orchestrator monitors result files by polling for `HIVE_TASK_COMPLETE` or `HIVE_TASK_ERROR` markers.

## Pipeline

The full `/hive` pipeline runs these phases in order:

```
1. Brainstorm     → Refine requirements through collaborative dialogue
2. Plan           → Generate tasks with model tags, batches, and dependencies
3. Design         → (Optional, UI projects) Create design system spec
4. Execute        → Dispatch workers in parallel batches via tmux
5. Validate       → (Optional, UI projects) Run Playwright UX tests
6. Security       → OWASP audit, zero CRITICAL/HIGH issues allowed
7. Ship           → Version, changelog, commit, push, PR
```

### Quality Gates

Each phase has an objective gate. Failure returns to the phase that failed:

- **Plan**: Tasks must be granular (2-5 min), have exact file paths, model tags, and dependency graph
- **Execute**: TDD mandatory, each task in isolated worktree, tests passing
- **Integrate**: Integration worker connects modules, integration tests pass
- **Security**: Zero CRITICAL or HIGH severity issues
- **Ship**: CHANGELOG updated, README updated, semver version bumped

## Key Principles

- **Invoke skills only when clearly applicable.** Wrong skill = wasted context.
- **Plans are the source of truth.** Workers read the plan; they do not improvise scope.
- **Worktrees enforce isolation.** No worker touches another worker's files.
- **Filesystem is the communication channel.** No tmux messaging, no shared memory.
- **Escalation is automatic.** Failed tasks retry, then escalate model tier, then block.
