---
name: dispatching-workers
description: "Dispatch parallel tmux workers to execute plan batches with model routing and failure recovery"
---

# Dispatching Workers

## Overview

This skill handles the execution phase of the Hive pipeline. It reads an approved plan, creates a tmux session, and for each batch launches parallel workers — each in its own git worktree, running Claude Code with the assigned model. The orchestrator monitors worker progress through the filesystem, handles failures with retry and escalation, and merges results after each batch.

Use this skill when a plan is approved and ready for execution, typically via `/hive-dispatch`.

## Process

### Step 1: Initialize Run

```bash
# Create run directory
RUN_ID=$(date +%Y%m%d-%H%M%S)
mkdir -p .hive/runs/$RUN_ID/{tasks,context}

# Copy plan and context
cp docs/plans/<plan-file>.md .hive/runs/$RUN_ID/plan.md
cp CLAUDE.md .hive/runs/$RUN_ID/context/
# Copy any other relevant context files (design docs, schemas)

# Initialize status
echo '{"run_id":"'$RUN_ID'","status":"running","current_batch":1}' > .hive/runs/$RUN_ID/status.json
```

### Step 2: Create tmux Session

```bash
# Source the tmux manager
source lib/tmux-manager.sh

# Create session for this run
hive_create_session "hive-$RUN_ID"
```

### Step 3: Execute Batches

For each batch in the plan, sequentially:

1. **Parse batch tasks** using `lib/plan-parser.sh`
2. **Create worktrees** for each task using `lib/worktree-manager.sh`
3. **Write assignment files** — one `task-N.assigned.json` per task
4. **Launch workers** — one tmux pane per task
5. **Monitor** — poll result files until all tasks complete or fail
6. **Handle failures** — retry, escalate, or block
7. **Merge worktrees** — combine completed work back to main branch
8. **Run integration** — if any task in the batch requires integration
9. **Run tests** — full test suite must pass before next batch
10. **Advance** — update status.json, move to next batch

### Step 4: Worker Launch

Workers are launched via wrapper scripts — **never** by sending the full claude command inline through `tmux send-keys`. Inline commands break when prompts contain single quotes, parentheses, `$`, backticks, or other shell metacharacters.

```bash
source lib/tmux-manager.sh

SCRIPT_PATH=".hive/runs/$RUN_ID/tasks/task-${N}.sh"
SIGNAL=$(hive_signal_channel "$RUN_ID" "$N")

hive_write_worker_script \
  "$SCRIPT_PATH" \
  ".hive/worktrees/task-$N" \
  "<model-id>" \
  "<budget-limit>" \
  "$TASK_PROMPT" \
  "$SYSTEM_PROMPT" \
  "$SIGNAL"

hive_create_worker "hive-$RUN_ID" "task-$N" ".hive/worktrees/task-$N"
hive_launch_worker_script "hive-$RUN_ID" "task-$N" "$SCRIPT_PATH"
```

Where:
- `<model-id>` is `claude-haiku-4-5`, `claude-sonnet-4-6`, or `claude-opus-4-6`
- `<budget-limit>` is scaled by model: Haiku=$0.50, Sonnet=$2.00, Opus=$5.00 (adjustable)
- `$TASK_PROMPT` and `$SYSTEM_PROMPT` are bash strings — any content is safe (written to files by `hive_write_worker_script`)
- `$SIGNAL` is the tmux wait-for channel; omit if not using event-driven synchronization

`hive_write_worker_script` writes the prompts to `task-N.task-prompt.txt` / `task-N.system-prompt.txt` alongside the script, and generates a wrapper that reads them at runtime. Only `bash /path/to/task-N.sh` is sent via `send-keys` — no metacharacters.

### Step 5: Worker Instruction Template

The system prompt appended to each worker includes:

```
You are a Hive worker executing a single task.

TASK: <task description from plan>
WORKTREE: .hive/worktrees/task-<N>/
RESULT FILE: .hive/runs/<run-id>/tasks/task-<N>.result.md

RULES:
- Work ONLY in your worktree directory
- Follow TDD: write test first, then implement
- When done, write your result file with HIVE_TASK_COMPLETE at the end
- On unrecoverable error, write result file with HIVE_TASK_ERROR at the end
- Do NOT modify files outside your worktree
- Do NOT communicate with other workers

ACCEPTANCE CRITERIA:
<acceptance criteria from plan>
```

## Monitoring

The orchestrator polls result files every 5 seconds:

```bash
source lib/result-collector.sh

# Check if all tasks in current batch are done
while [[ "$(hive_all_tasks_complete "$RUN_DIR" "$TASK_NUMBERS")" != "true" ]]; do
  sleep 5
  hive_get_tasks_by_status "$RUN_DIR" "error"
done
```

A task is complete when its result file contains either:
- `HIVE_TASK_COMPLETE` — success, ready to merge
- `HIVE_TASK_ERROR` — failure, needs retry or escalation

## Failure Recovery

When a worker writes `HIVE_TASK_ERROR`:

```
1. Parse error details from the result file
2. First failure  → Retry with same model (clean worktree, fresh launch)
3. Second failure → Escalate model tier:
   - Haiku  → Sonnet
   - Sonnet → Opus
   - Opus   → Mark task BLOCKED
4. BLOCKED task → Halt batch, log details, alert orchestrator
```

The orchestrator must decide whether to:
- Skip the blocked task and continue (if no downstream dependencies)
- Abort the run and return to planning phase
- Ask the user for intervention

## Worktree Merge

After all tasks in a batch succeed:

```bash
source lib/worktree-manager.sh

# Merge each task's worktree back to the working branch
for task in batch_tasks; do
  worktree_merge "task-$task"
done

# Clean up worktrees
for task in batch_tasks; do
  worktree_cleanup "task-$task"
done
```

If merge conflicts occur:
1. Attempt automatic resolution for trivial conflicts (both sides added different files)
2. For non-trivial conflicts, dispatch an integration worker with both versions as context
3. If integration worker cannot resolve, mark as BLOCKED

## Integration Phase

When any task in a batch has `Integration required: yes`:

1. All worktrees are merged first
2. A new integration worker is dispatched at `[Sonnet]` minimum
3. The integration worker receives all integration prompts from the batch
4. It wires modules together, fixes type mismatches, adds glue code
5. Integration tests run after the integration worker completes
6. If tests fail, the integration worker is re-dispatched with error output

## Shell Scripts

The dispatching process uses these library scripts:

| Script | Purpose |
|--------|---------|
| `lib/tmux-manager.sh` | Create/destroy tmux sessions, manage panes, launch workers |
| `lib/worktree-manager.sh` | Create, merge, and clean up git worktrees |
| `lib/result-collector.sh` | Poll result files, detect completion/error markers |
| `lib/plan-parser.sh` | Extract tasks, model tags, dependencies from plan markdown |

## Key Principles

- **One worker per task, one worktree per worker.** No shared mutable state between workers.
- **Batches are atomic.** All tasks in a batch must complete before the next batch starts.
- **Retry before escalate, escalate before block.** Maximize chance of automatic recovery.
- **Tests gate batch transitions.** The test suite must pass after merge before advancing.
- **Budget limits prevent runaway costs.** Each worker has a hard USD cap.
- **The plan is the contract.** Workers execute exactly what the plan specifies, nothing more.
