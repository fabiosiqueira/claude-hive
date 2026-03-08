---
description: "Dispatch parallel tmux workers to execute a Hive plan with model routing and failure recovery."
disable-model-invocation: true
---

# /hive-dispatch -- Parallel Worker Dispatcher

You are dispatching Hive workers to execute an approved plan in parallel batches via tmux.

## Step 1: Load Plan

Find the latest plan in `docs/plans/` (most recent by date prefix). If no plan exists, stop and tell the user to run `/hive-plan` first.

Read the plan and parse all batches, tasks, model assignments, and dependencies.

## Step 2: Initialize Run

Invoke the `hive:dispatching-workers` skill to set up the execution environment:

1. Generate run ID: `YYYYMMDD-HHMMSS` format
2. Create run directory: `.hive/runs/<run-id>/` with `tasks/` and `context/` subdirs
3. Copy the plan to `.hive/runs/<run-id>/plan.md`
4. Copy project context (`CLAUDE.md`, design docs) to `.hive/runs/<run-id>/context/`
5. Initialize `status.json` with run metadata

## Step 3: Create tmux Session

Create session via `lib/tmux-manager.sh`. Reuse if it already exists.

## Step 4: Execute Batches

For each batch in the plan, sequentially:

### 4a. Prepare Workers
- Create git worktrees for each task via `lib/worktree-manager.sh`
- Write assignment files (`task-N.assigned.json`) with model, max_turns, and instructions
- Set turn limits per model tier: Haiku=30, Sonnet=80, Opus=150

### 4b. Launch Workers
- Create one tmux pane per task in the session
- Launch each worker with the assigned model and task prompt
- Workers run in their own worktree with filesystem-based communication

### 4c. Monitor Progress

After launching all workers, show an initial status table, then start a background monitor that refreshes every 15 seconds while waiting for all signals:

```bash
source lib/tmux-manager.sh

# Initial status display
hive_print_status "$SESSION" "$RUN_DIR" "$BATCH_TASK_NUMBERS"

# Background monitor — refreshes every 15s while waiting
(while true; do
  sleep 15
  hive_print_status "$SESSION" "$RUN_DIR" "$BATCH_TASK_NUMBERS"
done) &
MONITOR_PID=$!

# Event-driven wait — returns when all workers signal done
hive_wait_for_all_workers "$ALL_SIGNALS"

# Stop monitor, show final state
kill "$MONITOR_PID" 2>/dev/null
hive_print_status "$SESSION" "$RUN_DIR" "$BATCH_TASK_NUMBERS"
echo "✓ Batch complete"
```

Update `status.json` as tasks complete.

### 4d. Handle Failures
- First failure: retry with same model (clean worktree, fresh launch)
- Second failure: escalate model tier (Haiku->Sonnet->Opus)
- Opus failure: mark task BLOCKED, halt batch, alert user

### 4e. Merge Results
- Merge completed worktrees back to working branch via `lib/worktree-manager.sh`
- If merge conflicts occur: dispatch integration worker to resolve
- Clean up worktrees after successful merge

### 4f. Integration
- If any task in the batch has `Integration required: yes`:
  - Dispatch integration worker (Sonnet minimum) with all integration prompts
  - Integration worker wires modules together, fixes type mismatches
  - Run integration tests after integration worker completes

### 4g. Test Gate
- Run full test suite after batch merge
- If tests fail: dispatch fix worker with test output as context
- Do NOT advance to next batch until tests pass

## Step 5: Generate Report

After all batches complete, generate a summary with: run ID, batch count, task count by model, retries, escalations, blocked tasks, and test status. Save report to `.hive/runs/<run-id>/report.md`.

## Gate

The dispatch is complete when:
- All batches executed with tests passing after each
- All worktrees merged and cleaned up
- No BLOCKED tasks remaining (or explicitly acknowledged by user)
- Summary report generated
