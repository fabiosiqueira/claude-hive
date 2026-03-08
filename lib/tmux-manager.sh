#!/usr/bin/env bash
# Hive tmux-manager.sh — Core tmux operations for worker orchestration
# Usage: source this file to get hive_* functions
# This file is meant to be sourced, not executed directly.
# Do NOT use set -euo pipefail here — functions return non-zero intentionally
# for status checks, and readonly vars would fail on re-source.

readonly HIVE_TMUX_PREFIX="hive"

# Check if tmux is available
hive_check_tmux() {
  command -v tmux >/dev/null 2>&1 || {
    echo "ERROR: tmux is not installed. Install with: brew install tmux" >&2
    return 1
  }
}

# Create a new tmux session for a hive run
# Args: session_name
hive_create_session() {
  local session_name="$1"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "ERROR: tmux session '$session_name' already exists" >&2
    return 1
  fi

  tmux new-session -d -s "$session_name" -n "orchestrator"
}

# Create a worker window in an existing session
# Args: session_name, worker_name, working_dir
hive_create_worker() {
  local session_name="$1"
  local worker_name="$2"
  local working_dir="${3:-$(pwd)}"

  tmux new-window -t "$session_name" -n "$worker_name" -c "$working_dir"
}

# Launch a command in a worker window
# Args: session_name, worker_name, command
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"

  tmux send-keys -t "$session_name:$worker_name" "$command" Enter
}

# Capture output from a worker window
# Args: session_name, worker_name, lines (default 50)
hive_capture_output() {
  local session_name="$1"
  local worker_name="$2"
  local lines="${3:-50}"

  tmux capture-pane -t "$session_name:$worker_name" -p -S "-$lines"
}

# Check if a worker window is alive (pane not dead)
# Args: session_name, worker_name
# Returns: "true" or "false"
hive_check_worker_alive() {
  local session_name="$1"
  local worker_name="$2"

  local dead
  dead=$(tmux list-panes -t "$session_name:$worker_name" -F "#{pane_dead}" 2>/dev/null || echo "1")

  if [[ "$dead" == "0" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Kill a worker window
# Args: session_name, worker_name
hive_kill_worker() {
  local session_name="$1"
  local worker_name="$2"

  tmux kill-window -t "$session_name:$worker_name" 2>/dev/null || true
}

# Kill an entire session
# Args: session_name
hive_kill_session() {
  local session_name="$1"

  tmux kill-session -t "$session_name" 2>/dev/null || true
}

# Build the claude command for a worker
# Args: model, system_prompt, max_budget, task_prompt, signal_channel (optional)
# Returns: the full command string
# If signal_channel is provided, appends `; tmux wait-for -S <channel>` so the
# orchestrator can block on `tmux wait-for <channel>` instead of polling.
hive_build_claude_command() {
  local model="$1"
  local system_prompt="$2"
  local max_budget="${3:-}"
  local task_prompt="${4:-}"
  local signal_channel="${5:-}"

  local cmd="claude --model '$model' --dangerously-skip-permissions"

  if [[ -n "$system_prompt" ]]; then
    # Save prompt to temp file — avoids quoting issues with special chars
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/hive-system-prompt.XXXXXX")
    printf '%s' "$system_prompt" > "$prompt_file"
    cmd="$cmd --append-system-prompt \"\$(cat '$prompt_file')\""
  fi

  if [[ -n "$max_budget" ]]; then
    cmd="$cmd --max-budget-usd '$max_budget'"
  fi

  if [[ -n "$task_prompt" ]]; then
    # Save prompt to temp file — avoids quoting issues with special chars
    local task_file
    task_file=$(mktemp "${TMPDIR:-/tmp}/hive-task-prompt.XXXXXX")
    printf '%s' "$task_prompt" > "$task_file"
    cmd="$cmd -p \"\$(cat '$task_file')\""
  fi

  if [[ -n "$signal_channel" ]]; then
    cmd="$cmd; tmux wait-for -S '$signal_channel'"
  fi

  echo "$cmd"
}

# Wait for a worker to signal completion (event-driven, no polling)
# Args: signal_channel
# Blocks until the worker signals via `tmux wait-for -S <channel>`
hive_wait_for_worker() {
  local signal_channel="$1"

  tmux wait-for "$signal_channel"
}

# Build a standard signal channel name for a task
# Args: run_id, task_number
# Returns: channel name string
hive_signal_channel() {
  local run_id="$1"
  local task_number="$2"

  echo "hive-${run_id}-task-${task_number}-done"
}

# Wait for all workers in a list to complete
# Args: signal_channels (space-separated list, or pass as positional args)
# Blocks until ALL channels have been signaled
hive_wait_for_all_workers() {
  local channels="$1"
  local channel

  for channel in $channels; do
    tmux wait-for "$channel"
  done
}
