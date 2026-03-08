---
name: collecting-results
description: "Aggregate worker results, manage merge process, and track run status through completion"
---

# Collecting Results

## Overview

After workers are dispatched, the orchestrator must monitor their progress, collect results, merge completed work back into the main branch, and handle errors. This skill covers the full result collection lifecycle: from polling result files to final cleanup. All coordination uses the filesystem — no tmux messaging.

## Monitoring Loop

The orchestrator polls worker result files at regular intervals. Use functions from `lib/result-collector.sh`:

```bash
source lib/result-collector.sh

RUN_DIR=".hive/runs/$RUN_ID"
POLL_INTERVAL_SECONDS=5

while true; do
  ALL_DONE=$(hive_all_tasks_complete "$RUN_DIR" "$TASK_NUMBERS")

  if [[ "$ALL_DONE" == "true" ]]; then
    break
  fi

  # Check for errors that need immediate attention
  ERRORED=$(hive_get_tasks_by_status "$RUN_DIR" "error")
  if [[ -n "$ERRORED" ]]; then
    # Handle errors (escalation, retry, or abort)
    break
  fi

  sleep "$POLL_INTERVAL_SECONDS"
done
```

Poll every 5 seconds. This balances responsiveness with filesystem overhead.

## Result File Parsing

Each worker writes a result file at `.hive/runs/<run-id>/tasks/task-<N>.result.md`. Parse it for completion markers:

| Marker | Meaning | Action |
|--------|---------|--------|
| `HIVE_TASK_COMPLETE` | Worker finished successfully | Proceed to merge |
| `HIVE_TASK_ERROR` | Worker encountered a failure | Trigger escalation or abort |
| Neither marker present | Worker still running or crashed | Keep polling; check if tmux pane is alive |

Use `hive_check_task_status "$RUN_DIR" "$TASK_NUMBER"` to get `"complete"`, `"error"`, or `"pending"`.

### Detecting Crashed Workers

If a task stays `pending` beyond a reasonable timeout, check whether the worker tmux pane is still alive:

```bash
source lib/tmux-manager.sh

ALIVE=$(hive_check_worker_alive "$SESSION_NAME" "task-$TASK_NUMBER")
if [[ "$ALIVE" == "false" ]]; then
  # Worker crashed without writing a result file
  hive_log_event "$RUN_DIR" "Task $TASK_NUMBER: worker crashed (no result, pane dead)"
  # Treat as error — trigger retry/escalation
fi
```

## Merge Strategy

After all tasks in a batch complete, merge their worktree branches back to the working branch. Merge sequentially in task number order:

```
Batch 1 tasks: [1, 2, 3]
Merge order:   task-1 -> task-2 -> task-3
```

For each task:

```bash
source lib/worktree-manager.sh

hive_worktree_merge "$REPO_PATH" "$RUN_ID" "$TASK_NUMBER"
```

Sequential order ensures deterministic results. Never merge in parallel — git does not handle concurrent merges.

## Conflict Detection

If `hive_worktree_merge` exits with a non-zero status, a merge conflict occurred.

When conflicts happen:

1. Identify the conflicting files from git output
2. Log the conflict in `.hive/runs/<run-id>/log.md`:
   ```
   - [timestamp] MERGE CONFLICT: task-3 conflicts with merged branch on files: src/api/routes.ts, src/types/index.ts
   ```
3. Decide how to resolve:
   - **Dispatch resolution worker**: create a new task with Sonnet or Opus to resolve the conflict
   - **Ask user**: if conflicts are in critical areas, ask the user for guidance
4. After resolution, continue the merge sequence from where it stopped

## Status Tracking

Update `.hive/runs/<run-id>/status.json` at each major transition using `hive_update_run_status`:

| Status | Meaning |
|--------|---------|
| `planning` | Plan is being created |
| `dispatching` | Workers are being launched |
| `running` | Workers are executing tasks |
| `integrating` | Integration worker is connecting modules |
| `complete` | All batches done, all merges successful |
| `failed` | Unrecoverable error, run aborted |

```bash
hive_update_run_status "$RUN_DIR" "running"
```

## Event Logging

Append every significant event to `.hive/runs/<run-id>/log.md` using `hive_log_event "$RUN_DIR" "<message>"`. Log both successes and failures — the log is the audit trail for the entire run.

## Final Aggregation

After all batches are merged and integration is complete:

1. Collect all task result files from `.hive/runs/<run-id>/tasks/`
2. Extract summaries from each `task-<N>.result.md`
3. Generate a run summary with:
   - Total tasks executed
   - Tasks per model tier
   - Tasks that required escalation
   - Total estimated cost
   - Files modified across all tasks
4. Write summary to `.hive/runs/<run-id>/summary.md`
5. Update run status to `complete`

## Cleanup

After a successful run, call `hive_worktree_cleanup_run "$REPO_PATH" "$RUN_ID"` from `lib/worktree-manager.sh` to remove all worktrees, branches, and the worktrees directory. Preserve the run directory (`.hive/runs/<run-id>/`) for audit. See the `git-worktrees` skill for full cleanup details.

## Error Handling

### Single Task Error

When one task writes `HIVE_TASK_ERROR`:

1. Read the error details from the result file
2. Log the error with `hive_log_event`
3. Decide: **retry**, **escalate**, or **abort batch**
   - If retries remain: re-dispatch with same model
   - If retry limit reached: escalate to next model tier
   - If Opus already failed: mark task BLOCKED
4. If task is BLOCKED but non-critical: continue batch with remaining tasks
5. If task is BLOCKED and other tasks depend on it: abort the batch

### Multiple Task Errors

If more than half the tasks in a batch error:

1. Abort the batch immediately
2. Log all error details
3. Update run status to `failed`
4. Report to orchestrator with a summary of failures
5. Suggest reviewing the plan — widespread failure usually means bad task specifications

### Unrecoverable Errors

If the merge process itself fails (corrupted worktree, git state issues):

1. Do not attempt further merges
2. Save the current state of all worktrees (do not clean up)
3. Log the git error output
4. Update run status to `failed`
5. Alert the user — manual git intervention may be needed

## Key Principles

- **Filesystem is the single source of truth.** Task status comes from result files, not tmux output.
- **Sequential merges only.** Never merge branches in parallel. Task number order within each batch.
- **Log everything.** Every transition, every error, every merge result goes into `log.md`.
- **Preserve evidence on failure.** Do not clean up worktrees or run directories when something fails.
- **Status.json reflects reality.** Update it at every transition so external tools can query run state.
- **Poll, don't push.** Workers write files; the orchestrator reads them. No reverse communication channel.
