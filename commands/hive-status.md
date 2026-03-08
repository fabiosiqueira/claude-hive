---
description: "Check status of running Hive workers -- tasks, models, elapsed time, and output."
disable-model-invocation: true
---

# /hive-status -- Worker Status Dashboard

You are checking the current status of Hive workers and runs.

## Step 1: Check Active tmux Sessions

List all Hive-related tmux sessions:

```bash
tmux list-sessions 2>/dev/null | grep "^hive-" || echo "No active Hive sessions"
```

For each session, list windows and panes:

```bash
tmux list-windows -t <session-name>
tmux list-panes -t <session-name> -F '#{pane_index} #{pane_pid} #{pane_dead}'
```

Report which workers are alive (running) and which are dead (finished or crashed).

## Step 2: Check Run Directory

Scan `.hive/runs/` for active runs:

```bash
ls -la .hive/runs/ 2>/dev/null || echo "No runs found"
```

For each run directory, read `status.json` to determine:
- Run ID and start time
- Current batch number
- Overall status (running, completed, blocked)

## Step 3: Task-Level Status

For each active run, check individual tasks in `.hive/runs/<run-id>/tasks/`:

- Files ending in `.assigned.json` -> task is assigned (pending or running)
- Files ending in `.result.md` containing `HIVE_TASK_COMPLETE` -> task succeeded
- Files ending in `.result.md` containing `HIVE_TASK_ERROR` -> task failed
- No result file yet -> task is still running

## Step 4: Capture Worker Output

For running workers, capture recent output from tmux panes:

```bash
tmux capture-pane -t <session>:<window>.<pane> -p -S -20
```

Show the last 20 lines of each running worker's output for visibility into progress.

## Step 5: Present Status Table

Format the results as a clear status table:

```
Run: <run-id> | Status: running | Batch: 2/4 | Elapsed: 3m 42s

| Task | Model   | Status    | Elapsed | Notes              |
|------|---------|-----------|---------|--------------------|
| 1    | Haiku   | complete  | 0:45    |                    |
| 2    | Sonnet  | complete  | 1:20    |                    |
| 3    | Haiku   | complete  | 0:32    |                    |
| 4    | Sonnet  | running   | 2:10    | Writing tests...   |
| 5    | Opus    | running   | 1:55    | Implementing auth  |
| 6    | Haiku   | pending   | --      | Blocked by batch 2 |
```

Include model distribution, completed/running/pending/failed counts, BLOCKED tasks with reason, and estimated time remaining. If no active runs exist, suggest `/hive-plan` or `/hive-dispatch`.
