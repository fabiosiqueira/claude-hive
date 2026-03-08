#!/usr/bin/env bash
# lib/result-collector.sh — Manages .hive/runs/<run-id>/ directory structure
# Meant to be sourced, NOT executed directly. Do NOT use set -euo pipefail here.

# Initialize a run directory with all subdirectories and initial files.
# Args: base_path, run_id
# Output: path to the run directory
hive_init_run() {
  local base_path="$1"
  local run_id="$2"
  local run_dir="$base_path/.hive/runs/$run_id"

  mkdir -p "$run_dir/context"
  mkdir -p "$run_dir/tasks"

  # Only create status.json and log.md if they don't already exist (idempotent)
  if [[ ! -f "$run_dir/status.json" ]]; then
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    printf '{"run_id": "%s", "status": "planning", "updated_at": "%s"}\n' \
      "$run_id" "$timestamp" > "$run_dir/status.json"
  fi

  if [[ ! -f "$run_dir/log.md" ]]; then
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    printf '# Hive Run Log\n\n- [%s] Run initialized: %s\n' \
      "$timestamp" "$run_id" > "$run_dir/log.md"
  fi

  echo "$run_dir"
}

# Write a task assignment file.
# Args: run_dir, task_number, model, worktree_path
hive_assign_task() {
  local run_dir="$1"
  local task_number="$2"
  local model="$3"
  local worktree_path="$4"

  local task_file="$run_dir/tasks/task-${task_number}.assigned.json"
  printf '{"task_number": %s, "model": "%s", "status": "assigned", "worktree_path": "%s"}\n' \
    "$task_number" "$model" "$worktree_path" > "$task_file"
}

# Check if a task result file exists and contains a completion marker.
# Args: run_dir, task_number
# Output: "complete", "error", or "pending"
hive_check_task_status() {
  local run_dir="$1"
  local task_number="$2"
  local result_file="$run_dir/tasks/task-${task_number}.result.md"

  if [[ ! -f "$result_file" ]]; then
    echo "pending"
    return 0
  fi

  local content
  content=$(cat "$result_file")

  if [[ "$content" == *"HIVE_TASK_COMPLETE"* ]]; then
    echo "complete"
  elif [[ "$content" == *"HIVE_TASK_ERROR"* ]]; then
    echo "error"
  else
    echo "pending"
  fi
}

# Get all tasks with a specific status.
# Args: run_dir, status (complete|error|pending)
# Output: space-separated task numbers
hive_get_tasks_by_status() {
  local run_dir="$1"
  local target_status="$2"
  local matching=()

  # Find all assigned task files to get the list of task numbers
  local tasks_dir="$run_dir/tasks"
  if [[ ! -d "$tasks_dir" ]]; then
    echo ""
    return 0
  fi

  local task_file
  for task_file in "$tasks_dir"/task-*.assigned.json; do
    # Handle glob that matches nothing
    [[ -f "$task_file" ]] || continue

    # Extract task number from filename: task-<N>.assigned.json
    local basename
    basename=$(basename "$task_file")
    local task_number="${basename#task-}"
    task_number="${task_number%.assigned.json}"

    local status
    status=$(hive_check_task_status "$run_dir" "$task_number")

    if [[ "$status" == "$target_status" ]]; then
      matching+=("$task_number")
    fi
  done

  echo "${matching[*]}"
}

# Check if all tasks in a list are complete.
# Args: run_dir, task_numbers (space-separated)
# Output: "true" or "false"
hive_all_tasks_complete() {
  local run_dir="$1"
  local task_numbers="$2"

  # Empty list means all are complete (vacuous truth)
  if [[ -z "$task_numbers" ]]; then
    echo "true"
    return 0
  fi

  local task_number
  for task_number in $task_numbers; do
    local status
    status=$(hive_check_task_status "$run_dir" "$task_number")
    if [[ "$status" != "complete" ]]; then
      echo "false"
      return 0
    fi
  done

  echo "true"
}

# Write to the run log.
# Args: run_dir, message
hive_log_event() {
  local run_dir="$1"
  local message="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")

  printf -- '- [%s] %s\n' "$timestamp" "$message" >> "$run_dir/log.md"
}

# Update run status.
# Args: run_dir, status (planning|dispatching|running|integrating|complete|failed)
hive_update_run_status() {
  local run_dir="$1"
  local new_status="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")

  # Extract run_id from current status.json
  local run_id=""
  if [[ -f "$run_dir/status.json" ]]; then
    local content
    content=$(cat "$run_dir/status.json")
    # Extract run_id value using parameter expansion
    # Content looks like: {"run_id": "abc123", ...}
    local after_key="${content#*\"run_id\": \"}"
    run_id="${after_key%%\"*}"
  fi

  printf '{"run_id": "%s", "status": "%s", "updated_at": "%s"}\n' \
    "$run_id" "$new_status" "$timestamp" > "$run_dir/status.json"
}

# Get run status.
# Args: run_dir
# Output: status string
hive_get_run_status() {
  local run_dir="$1"

  if [[ ! -f "$run_dir/status.json" ]]; then
    echo "unknown"
    return 1
  fi

  local content
  content=$(cat "$run_dir/status.json")
  # Extract status value: {"run_id": "...", "status": "running", ...}
  local after_key="${content#*\"status\": \"}"
  local status="${after_key%%\"*}"
  echo "$status"
}

# Clean up a run directory.
# Args: base_path, run_id
hive_cleanup_run() {
  local base_path="$1"
  local run_id="$2"
  local run_dir="$base_path/.hive/runs/$run_id"

  if [[ -d "$run_dir" ]]; then
    rm -rf "$run_dir"
  fi
}
