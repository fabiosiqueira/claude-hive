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
# WARNING: Only safe for commands without single quotes, parentheses, or other
# shell metacharacters. For claude invocations with arbitrary prompts,
# use hive_write_worker_script + hive_launch_worker_script instead.
# NOTE: Uses :=worker_name (exact match) to prevent tmux prefix-matching the
# window name against the session name when both contain hyphens (tmux >= 3.x).
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"

  tmux send-keys -t "$session_name:=$worker_name" "$command" Enter
}

# Launch a worker using a pre-written script (preferred over hive_launch_worker)
# Avoids shell quoting issues: only the script path is sent via send-keys.
# Args: session_name, worker_name, script_path
hive_launch_worker_script() {
  local session_name="$1"
  local worker_name="$2"
  local script_path="$3"

  tmux send-keys -t "$session_name:=$worker_name" "bash $(printf '%q' "$script_path")" Enter
}

# Capture output from a worker window
# Args: session_name, worker_name, lines (default 50)
hive_capture_output() {
  local session_name="$1"
  local worker_name="$2"
  local lines="${3:-50}"

  tmux capture-pane -t "$session_name:=$worker_name" -p -S "-$lines"
}

# Check if a worker window is alive (pane not dead)
# Args: session_name, worker_name
# Returns: "true" or "false"
hive_check_worker_alive() {
  local session_name="$1"
  local worker_name="$2"

  local dead
  dead=$(tmux list-panes -t "$session_name:=$worker_name" -F "#{pane_dead}" 2>/dev/null || echo "1")

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

  tmux kill-window -t "$session_name:=$worker_name" 2>/dev/null || true
}

# Kill an entire session
# Args: session_name
hive_kill_session() {
  local session_name="$1"

  tmux kill-session -t "$session_name" 2>/dev/null || true
}

# Kill all active Hive workers and tmux sessions.
# Safe to call at any time — idempotent, ignores missing sessions/processes.
hive_cleanup_all() {
  pkill -f "dangerously-skip-permissions" 2>/dev/null || true
  tmux list-sessions 2>/dev/null \
    | grep "^hive-" \
    | awk -F: '{print $1}' \
    | xargs -I{} tmux kill-session -t {} 2>/dev/null || true
}

# Write a self-contained wrapper script for a worker.
# Stores prompts as separate files and reads them at runtime — avoids the shell
# quoting issues that occur when long prompts are sent inline via tmux send-keys.
# Prompt files are written alongside the script with .task-prompt.txt /
# .system-prompt.txt suffixes. Use hive_launch_worker_script to run the script.
# Args: script_path, worktree_path, model, max_turns,
#       task_prompt (string), system_prompt (string, optional)
# max_turns: limits worker turns to prevent infinite loops (works with all plans,
#            including Claude Max subscription — unlike --max-budget-usd which
#            requires API billing). Defaults: Haiku=15, Sonnet=30, Opus=60.
# NOTE: signal_channel (7th arg) was removed in v1.1.0. Workers no longer use
# tmux wait-for. Orchestrator monitors via file polling (hive_get_task_status).
hive_write_worker_script() {
  local script_path="$1"
  local worktree_path="$2"
  local model="$3"
  local max_turns="${4:-}"
  local task_prompt="${5:-}"
  local system_prompt="${6:-}"

  local task_prompt_file="${script_path%.sh}.task-prompt.txt"
  local system_prompt_file="${script_path%.sh}.system-prompt.txt"

  if [[ -n "$task_prompt" ]]; then
    printf '%s' "$task_prompt" > "$task_prompt_file"
  fi

  if [[ -n "$system_prompt" ]]; then
    printf '%s' "$system_prompt" > "$system_prompt_file"
  fi

  local abs_worktree_path="$worktree_path"
  if [[ "$worktree_path" != /* ]]; then
    abs_worktree_path="$(pwd)/$worktree_path"
  fi

  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -uo pipefail\n'

    printf 'cd %q\n\n' "$abs_worktree_path"

    if [[ -n "$task_prompt" ]]; then
      printf '_task_prompt=$(cat %q)\n' "$task_prompt_file"
    fi

    if [[ -n "$system_prompt" ]]; then
      printf '_system_prompt=$(cat %q)\n' "$system_prompt_file"
    fi

    printf '\nclaude --model %q --dangerously-skip-permissions' "$model"

    if [[ -n "$system_prompt" ]]; then
      printf ' \\\n  --append-system-prompt "$_system_prompt"'
    fi

    if [[ -n "$max_turns" ]]; then
      printf ' \\\n  --max-turns %q' "$max_turns"
    fi

    if [[ -n "$task_prompt" ]]; then
      printf ' \\\n  -p "$_task_prompt"'
    fi

    printf '\n'
  } > "$script_path"

  chmod +x "$script_path"
}

# Aguarda result file conter marker terminal — polling sem race condition.
# Substitui tmux wait-for: não há sinal que pode ser perdido, apenas polling de arquivo.
# Args: result_file, timeout_seconds (default 3600), interval_seconds (default 5)
# Returns: 0 se encontrou marker terminal, 1 se timeout
hive_wait_for_result() {
  local result_file="$1"
  local timeout="${2:-3600}"
  local interval="${3:-5}"
  local elapsed=0

  while [[ $elapsed -lt $timeout ]]; do
    if grep -qE "HIVE_TASK_COMPLETE|HIVE_TASK_ERROR|HIVE_TASK_CONTEXT_HEAVY" "$result_file" 2>/dev/null; then
      return 0
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  return 1
}

# Retorna status terminal de uma task lendo o result file.
# Args: result_file
# Returns (stdout): "complete" | "error" | "context_heavy" | "running"
hive_get_task_status() {
  local result_file="$1"

  if [[ ! -f "$result_file" ]]; then
    echo "running"
    return 0
  fi

  if grep -q "HIVE_TASK_COMPLETE" "$result_file" 2>/dev/null; then
    echo "complete"
  elif grep -q "HIVE_TASK_ERROR" "$result_file" 2>/dev/null; then
    echo "error"
  elif grep -q "HIVE_TASK_CONTEXT_HEAVY" "$result_file" 2>/dev/null; then
    echo "context_heavy"
  else
    echo "running"
  fi
}

# Retorna última linha do progress file sem o timestamp [HH:MM:SS].
# Args: run_dir, task_number
# Returns (stdout): string de progresso ou vazio se arquivo não existe
hive_get_task_progress() {
  local run_dir="$1"
  local task_number="$2"
  local progress_file="$run_dir/tasks/task-$task_number.progress.txt"

  if [[ ! -f "$progress_file" ]]; then
    echo ""
    return 0
  fi

  local last_line
  last_line=$(tail -1 "$progress_file" 2>/dev/null || echo "")
  # Strip timestamp prefix [HH:MM:SS] if present
  echo "$last_line" | sed 's/^\[[0-9:]*\] //'
}

# DEPRECATED (v1.1.0): Use hive_write_worker_script + hive_launch_worker_script instead.
# signal_channel (5th arg) is IGNORED — tmux wait-for was removed in v1.1.0.
# This function builds an unsafe command string (metacharacter issues with tmux send-keys).
hive_build_claude_command() {
  local model="$1"
  local system_prompt="$2"
  local max_turns="${3:-}"
  local task_prompt="${4:-}"
  # signal_channel (5th arg) intentionally ignored — tmux wait-for removed in v1.1.0

  local cmd="claude --model '$model' --dangerously-skip-permissions"

  if [[ -n "$system_prompt" ]]; then
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/hive-system-prompt.XXXXXX")
    printf '%s' "$system_prompt" > "$prompt_file"
    cmd="$cmd --append-system-prompt \"\$(cat '$prompt_file')\""
  fi

  if [[ -n "$max_turns" ]]; then
    cmd="$cmd --max-turns '$max_turns'"
  fi

  if [[ -n "$task_prompt" ]]; then
    local task_file
    task_file=$(mktemp "${TMPDIR:-/tmp}/hive-task-prompt.XXXXXX")
    printf '%s' "$task_prompt" > "$task_file"
    cmd="$cmd -p \"\$(cat '$task_file')\""
  fi

  echo "$cmd"
}

# DEPRECATED (v1.1.0): Use hive_wait_for_result instead.
# tmux wait-for has a race condition: if the worker signals before the
# orchestrator calls wait-for, the signal is lost and the orchestrator hangs.
# hive_wait_for_result uses file polling which is immune to this race.
hive_wait_for_worker() {
  # DEPRECATED (v1.1.0): tmux wait-for removed — race condition risk.
  # Use hive_wait_for_result (file polling) instead.
  echo "ERROR: hive_wait_for_worker is deprecated. Use hive_wait_for_result instead." >&2
  return 1
}

# DEPRECATED (v1.1.0): signal_channel was removed from hive_write_worker_script.
# Workers no longer signal via tmux. Orchestrator polls via hive_get_task_status.
hive_signal_channel() {
  local run_id="$1"
  local task_number="$2"

  echo "hive-${run_id}-task-${task_number}-done"
}

# Print live status table for all tasks in a batch
# Args: session_name, run_dir, task_numbers (space-separated)
hive_print_status() {
  local session_name="$1"
  local run_dir="$2"
  local task_numbers="$3"

  echo ""
  echo "┌── Status $(date +%H:%M:%S) ────────────────────────────────────────────"
  printf "│ %-6s %-22s %-12s %-8s %s\n" "Task" "Model" "Status" "Elapsed" "Progress"
  echo "│ ─────────────────────────────────────────────────────────────────────"

  for N in $task_numbers; do
    local assigned="$run_dir/tasks/task-$N.assigned.json"
    local result="$run_dir/tasks/task-$N.result.md"
    local progress="$run_dir/tasks/task-$N.progress.txt"

    local model="?"
    [[ -f "$assigned" ]] && model=$(jq -r '.model // "?"' "$assigned" 2>/dev/null || echo "?")

    local task_status="pending"
    local elapsed="--"
    if [[ -f "$assigned" ]]; then
      task_status="running"
      local start now secs
      start=$(stat -f %m "$assigned" 2>/dev/null || stat -c %Y "$assigned" 2>/dev/null || echo 0)
      now=$(date +%s)
      secs=$(( now - start ))
      elapsed="$(( secs / 60 ))m$(( secs % 60 ))s"
    fi
    grep -q "HIVE_TASK_COMPLETE" "$result" 2>/dev/null && task_status="✓ done"
    grep -q "HIVE_TASK_ERROR"    "$result" 2>/dev/null && task_status="✗ error"

    # NOTE: hive_capture_output is useless here — Claude CLI buffers tmux output
    # until completion. Progress file is the only reliable source of live status.
    local last_progress=""
    [[ -f "$progress" ]] && last_progress=$(tail -1 "$progress" 2>/dev/null | cut -c1-45 || echo "")

    printf "│ %-6s %-22s %-12s %-8s %s\n" "$N" "$model" "$task_status" "$elapsed" "$last_progress"
  done

  echo "└──────────────────────────────────────────────────────────────────────"
}

# DEPRECATED (v1.1.0): Use hive_get_task_status polling loop in the orchestrator instead.
# See skills/dispatching-workers/SKILL.md Step 5 for the TodoWrite + polling pattern.
hive_wait_for_all_workers() {
  # DEPRECATED (v1.1.0): tmux wait-for removed — race condition risk.
  # Use the TaskCreate/TaskUpdate polling loop in the orchestrator instead.
  echo "ERROR: hive_wait_for_all_workers is deprecated. Use file polling + TaskCreate/TaskUpdate." >&2
  return 1
}
