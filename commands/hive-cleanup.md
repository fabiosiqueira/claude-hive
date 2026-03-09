---
description: "Kill all active Hive workers and tmux sessions, clean up orphaned processes."
disable-model-invocation: true
---

# /hive-cleanup -- Emergency Cleanup

Kill all active Hive workers, tmux sessions, and orphaned Claude processes.

## Step 1: Kill worker processes

```bash
pkill -f "dangerously-skip-permissions" 2>/dev/null; echo "Workers killed"
```

If no processes found, that's fine — continue.

## Step 2: Kill all Hive tmux sessions

```bash
tmux list-sessions 2>/dev/null | grep "^hive-" | awk -F: '{print $1}' | xargs -I{} tmux kill-session -t {} 2>/dev/null
echo "Tmux sessions cleaned"
```

## Step 3: Verify

```bash
ps aux | grep "dangerously-skip-permissions" | grep -v grep | wc -l
tmux list-sessions 2>/dev/null | grep "^hive-" | wc -l
```

Both counts must be 0. If not, report which PIDs remain.

## Step 4: Report

Print a one-line summary:
- How many worker processes were killed
- How many tmux sessions were closed
- Any PIDs that could not be killed
