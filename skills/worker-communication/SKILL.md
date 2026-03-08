---
name: worker-communication
description: "Filesystem-based protocol for worker coordination — directory structure, task files, result format"
---

# Worker Communication

## Overview

Hive workers coordinate exclusively through the filesystem. The orchestrator writes assignment files, workers write result files, and the orchestrator polls for completion. No tmux send-keys, no shared memory, no real-time channels. This design is simple, debuggable, and resilient to worker crashes.

## Directory Structure

Every run creates a directory under `.hive/runs/`:

```
.hive/runs/<run-id>/
├── plan.md                          # Full plan (read-only for workers)
├── context/                         # Shared project context
│   ├── CLAUDE.md                    # Project conventions
│   ├── design.md                    # Design document (if exists)
│   └── <other relevant files>       # Schemas, configs, etc.
├── tasks/                           # Task assignments and results
│   ├── task-1.assigned.json         # Assignment metadata
│   ├── task-1.result.md             # Worker output (written by worker)
│   ├── task-2.assigned.json
│   ├── task-2.result.md
│   └── ...
├── status.json                      # Aggregated run state
└── log.md                           # Chronological event log
```

## Task Assignment File

The orchestrator writes one `task-N.assigned.json` per task before launching the worker:

```json
{
  "task_id": 1,
  "batch": 1,
  "model": "claude-sonnet-4-6",
  "complexity": "moderate",
  "status": "assigned",
  "worktree_path": ".hive/worktrees/task-1/",
  "result_path": ".hive/runs/<run-id>/tasks/task-1.result.md",
  "description": "Implement user registration API endpoint",
  "files": ["src/api/routes/auth/register.ts", "src/services/auth.ts"],
  "depends_on": [],
  "acceptance": "Tests pass for valid registration, duplicate email, invalid input",
  "assigned_at": "2026-03-08T14:30:00Z"
}
```

Fields:

| Field | Type | Description |
|-------|------|-------------|
| `task_id` | number | Unique task identifier within the plan |
| `batch` | number | Which batch this task belongs to |
| `model` | string | Claude model ID to use |
| `complexity` | string | `simple`, `moderate`, or `complex` |
| `status` | string | `assigned`, `running`, `complete`, `error`, `blocked` |
| `worktree_path` | string | Path to the worker's isolated worktree |
| `result_path` | string | Where the worker must write its result |
| `description` | string | What the worker must do |
| `files` | string[] | Files the worker will create or modify |
| `depends_on` | number[] | Task IDs that must complete first |
| `acceptance` | string | Observable criteria for task completion |
| `assigned_at` | string | ISO timestamp of assignment |

## Task Result File

Workers write their result to `task-N.result.md` when they finish. This file is the worker's only output channel.

### Success Format

```markdown
# Task 1 Result

## Status
COMPLETE

## Files Changed
- src/api/routes/auth/register.ts (created)
- src/services/auth.ts (created)
- src/api/routes/auth/__tests__/register.test.ts (created)

## Test Results
- 5 tests passed, 0 failed
- Coverage: 94% lines, 88% branches

## Notes
Used Zod for input validation. Email uniqueness enforced at DB level with unique constraint.

HIVE_TASK_COMPLETE
```

### Error Format

```markdown
# Task 1 Result

## Status
ERROR

## Error Details
Prisma schema has no User model. Dependency missing.

## Files Changed
- src/api/routes/auth/__tests__/register.test.ts (created, failing)

## Attempted Recovery
1. Checked schema files — User model not found
2. Missing dependency, not a code error

HIVE_TASK_ERROR
```

## Completion Markers

The last line of every result file must be exactly one of:

| Marker | Meaning |
|--------|---------|
| `HIVE_TASK_COMPLETE` | Task succeeded. All acceptance criteria met. |
| `HIVE_TASK_ERROR` | Task failed. Error details in the file. |

The orchestrator detects completion by scanning for these exact strings at the end of result files. Workers must always write a result file, even on catastrophic failure.

## Status File

The orchestrator maintains `status.json` at the run level:

```json
{
  "run_id": "20260308-143000",
  "status": "running",
  "current_batch": 2,
  "total_batches": 4,
  "tasks": {
    "total": 12,
    "complete": 5,
    "running": 3,
    "error": 0,
    "blocked": 0,
    "pending": 4
  },
  "started_at": "2026-03-08T14:30:00Z",
  "updated_at": "2026-03-08T14:45:12Z"
}
```

The orchestrator updates this file after every state change (task completion, batch transition, error).

## Event Log

The `log.md` file records significant events chronologically:

```markdown
# Run Log: 20260308-143000

- [14:30:00] Run started. Plan: docs/plans/2026-03-08-auth.md
- [14:30:02] Batch 1 started. Tasks: 1, 2, 3
- [14:30:03] Task 1 assigned to claude-sonnet-4-6
- [14:32:15] Task 2 complete. 3 files changed, 4 tests passed.
- [14:35:10] Task 1 complete. 3 files changed, 5 tests passed.
- [14:35:12] Batch 1 integration started.
- [14:37:01] Batch 2 started. Tasks: 4, 5
```

## Worker Rules

Workers must follow these rules strictly:

1. **Read plan.md and context/ for orientation.** Understand the project before writing code.
2. **Work only in your assigned worktree.** Never modify files in the main branch or other worktrees.
3. **Follow TDD.** Write the test first, confirm it fails, then implement.
4. **Write your result file when done.** This is your only output. No result file = the orchestrator assumes you are still running.
5. **Always include a completion marker.** `HIVE_TASK_COMPLETE` or `HIVE_TASK_ERROR` as the last line.
6. **Include error details on failure.** The orchestrator needs to know why you failed to decide retry vs. escalate.
7. **Do not communicate with other workers.** No reading other workers' result files, no modifying shared state.
8. **Do not exceed your scope.** If the task says "create registration endpoint", do not also refactor the login endpoint.

## Communication Direction

Communication is strictly one-way per channel:
- **Orchestrator → Worker**: assignment files, plan, context
- **Worker → Orchestrator**: result files

The orchestrator polls result files every 5 seconds checking for completion markers. It never writes to result files.

## Key Principles

- **Filesystem is the single communication channel.** No tmux send-keys, no pipes, no sockets.
- **Workers are stateless.** They read their assignment, do the work, write the result, and exit.
- **Result files are immutable.** Once written, neither the worker nor the orchestrator modifies them.
- **Completion markers are the handshake.** The orchestrator only acts on files with a marker.
- **One-way communication per channel.** Assignment flows down, results flow up. No bidirectional channels.
- **Always write a result, even on failure.** A missing result file is the worst outcome — the orchestrator cannot distinguish "still running" from "crashed silently".
