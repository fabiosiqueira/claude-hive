#!/usr/bin/env bash
# Tests for lib/result-collector.sh
# Note: set -e is NOT used here because we need to test failure cases
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hive-test-result-collector-XXXXXX")

source "$LIB_DIR/result-collector.sh" 2>/dev/null || true

assert_eq() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_contains() {
  local description="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected to contain: $needle"
    echo "    actual:              $haystack"
    ((FAIL++))
  fi
}

assert_file_exists() {
  local description="$1"
  local filepath="$2"
  if [[ -f "$filepath" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    file does not exist: $filepath"
    ((FAIL++))
  fi
}

assert_dir_exists() {
  local description="$1"
  local dirpath="$2"
  if [[ -d "$dirpath" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    directory does not exist: $dirpath"
    ((FAIL++))
  fi
}

assert_dir_not_exists() {
  local description="$1"
  local dirpath="$2"
  if [[ ! -d "$dirpath" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    directory should not exist: $dirpath"
    ((FAIL++))
  fi
}

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# --- Tests ---

echo "=== result-collector.sh tests ==="
echo ""

# ---------- hive_init_run ----------
echo "--- hive_init_run ---"

run_path=$(hive_init_run "$TEST_DIR" "run-001")
assert_eq "returns run directory path" "$TEST_DIR/.hive/runs/run-001" "$run_path"
assert_dir_exists "creates run directory" "$TEST_DIR/.hive/runs/run-001"
assert_dir_exists "creates context subdirectory" "$TEST_DIR/.hive/runs/run-001/context"
assert_dir_exists "creates tasks subdirectory" "$TEST_DIR/.hive/runs/run-001/tasks"
assert_file_exists "creates status.json" "$TEST_DIR/.hive/runs/run-001/status.json"
assert_file_exists "creates log.md" "$TEST_DIR/.hive/runs/run-001/log.md"

status_content=$(cat "$TEST_DIR/.hive/runs/run-001/status.json")
assert_contains "status.json contains run_id" '"run_id": "run-001"' "$status_content"
assert_contains "status.json contains planning status" '"status": "planning"' "$status_content"

log_content=$(cat "$TEST_DIR/.hive/runs/run-001/log.md")
assert_contains "log.md has header" "# Hive Run Log" "$log_content"
assert_contains "log.md has init event" "Run initialized" "$log_content"

echo ""

# ---------- hive_assign_task ----------
echo "--- hive_assign_task ---"

RUN_DIR="$TEST_DIR/.hive/runs/run-001"

hive_assign_task "$RUN_DIR" 1 "sonnet" "/tmp/worktree-1"
assert_file_exists "creates task assignment file" "$RUN_DIR/tasks/task-1.assigned.json"

assign_content=$(cat "$RUN_DIR/tasks/task-1.assigned.json")
assert_contains "assignment has task_number" '"task_number": 1' "$assign_content"
assert_contains "assignment has model" '"model": "sonnet"' "$assign_content"
assert_contains "assignment has status" '"status": "assigned"' "$assign_content"
assert_contains "assignment has worktree_path" '"worktree_path": "/tmp/worktree-1"' "$assign_content"

hive_assign_task "$RUN_DIR" 2 "haiku" "/tmp/worktree-2"
assert_file_exists "creates second task assignment" "$RUN_DIR/tasks/task-2.assigned.json"

echo ""

# ---------- hive_check_task_status ----------
echo "--- hive_check_task_status ---"

# No result file yet -> pending
status=$(hive_check_task_status "$RUN_DIR" 1)
assert_eq "task without result file is pending" "pending" "$status"

# Create a result file with HIVE_TASK_COMPLETE marker
echo "## Task 1 Result
HIVE_TASK_COMPLETE
All changes applied successfully." > "$RUN_DIR/tasks/task-1.result.md"

status=$(hive_check_task_status "$RUN_DIR" 1)
assert_eq "task with COMPLETE marker is complete" "complete" "$status"

# Create a result file with HIVE_TASK_ERROR marker
echo "## Task 2 Result
HIVE_TASK_ERROR
Failed to compile." > "$RUN_DIR/tasks/task-2.result.md"

status=$(hive_check_task_status "$RUN_DIR" 2)
assert_eq "task with ERROR marker is error" "error" "$status"

# Create a result file without any marker
hive_assign_task "$RUN_DIR" 3 "opus" "/tmp/worktree-3"
echo "## Task 3 Result
Some partial output without markers." > "$RUN_DIR/tasks/task-3.result.md"

status=$(hive_check_task_status "$RUN_DIR" 3)
assert_eq "task with result but no marker is pending" "pending" "$status"

echo ""

# ---------- hive_get_tasks_by_status ----------
echo "--- hive_get_tasks_by_status ---"

complete_tasks=$(hive_get_tasks_by_status "$RUN_DIR" "complete")
assert_eq "gets complete tasks" "1" "$complete_tasks"

error_tasks=$(hive_get_tasks_by_status "$RUN_DIR" "error")
assert_eq "gets error tasks" "2" "$error_tasks"

pending_tasks=$(hive_get_tasks_by_status "$RUN_DIR" "pending")
assert_eq "gets pending tasks" "3" "$pending_tasks"

echo ""

# ---------- hive_all_tasks_complete ----------
echo "--- hive_all_tasks_complete ---"

result=$(hive_all_tasks_complete "$RUN_DIR" "1")
assert_eq "single complete task returns true" "true" "$result"

result=$(hive_all_tasks_complete "$RUN_DIR" "1 2")
assert_eq "mix of complete and error returns false" "false" "$result"

result=$(hive_all_tasks_complete "$RUN_DIR" "1 3")
assert_eq "mix of complete and pending returns false" "false" "$result"

# Make task 3 complete too
echo "HIVE_TASK_COMPLETE" > "$RUN_DIR/tasks/task-3.result.md"
result=$(hive_all_tasks_complete "$RUN_DIR" "1 3")
assert_eq "all complete tasks returns true" "true" "$result"

echo ""

# ---------- hive_log_event ----------
echo "--- hive_log_event ---"

hive_log_event "$RUN_DIR" "Task 1 started"
hive_log_event "$RUN_DIR" "Task 2 started"

log_content=$(cat "$RUN_DIR/log.md")
assert_contains "log contains first event" "Task 1 started" "$log_content"
assert_contains "log contains second event" "Task 2 started" "$log_content"
assert_contains "log events have timestamps" "T" "$log_content"

echo ""

# ---------- hive_update_run_status / hive_get_run_status ----------
echo "--- hive_update_run_status / hive_get_run_status ---"

hive_update_run_status "$RUN_DIR" "running"
status=$(hive_get_run_status "$RUN_DIR")
assert_eq "status updated to running" "running" "$status"

hive_update_run_status "$RUN_DIR" "integrating"
status=$(hive_get_run_status "$RUN_DIR")
assert_eq "status updated to integrating" "integrating" "$status"

hive_update_run_status "$RUN_DIR" "complete"
status=$(hive_get_run_status "$RUN_DIR")
assert_eq "status updated to complete" "complete" "$status"

# Verify the JSON structure
status_json=$(cat "$RUN_DIR/status.json")
assert_contains "status.json has run_id after update" '"run_id": "run-001"' "$status_json"
assert_contains "status.json has updated_at" '"updated_at":' "$status_json"

echo ""

# ---------- hive_cleanup_run ----------
echo "--- hive_cleanup_run ---"

# Create a second run to clean up
hive_init_run "$TEST_DIR" "run-to-delete"
assert_dir_exists "run-to-delete exists before cleanup" "$TEST_DIR/.hive/runs/run-to-delete"

hive_cleanup_run "$TEST_DIR" "run-to-delete"
assert_dir_not_exists "run-to-delete removed after cleanup" "$TEST_DIR/.hive/runs/run-to-delete"

# Original run should still exist
assert_dir_exists "run-001 still exists after other cleanup" "$TEST_DIR/.hive/runs/run-001"

echo ""

# ---------- Edge cases ----------
echo "--- Edge cases ---"

# hive_check_task_status for non-existent task (no assignment file, no result file)
status=$(hive_check_task_status "$RUN_DIR" 99)
assert_eq "non-existent task is pending" "pending" "$status"

# hive_get_tasks_by_status when no tasks match
# Create a fresh run with no tasks
fresh_run=$(hive_init_run "$TEST_DIR" "run-empty")
empty_result=$(hive_get_tasks_by_status "$fresh_run" "complete")
assert_eq "no tasks returns empty string" "" "$empty_result"

# hive_all_tasks_complete with empty task list
result=$(hive_all_tasks_complete "$RUN_DIR" "")
assert_eq "empty task list returns true" "true" "$result"

echo ""

# ---------- Multiple inits are idempotent ----------
echo "--- Idempotent init ---"

hive_log_event "$RUN_DIR" "Before re-init"
run_path_again=$(hive_init_run "$TEST_DIR" "run-001")
assert_eq "re-init returns same path" "$RUN_DIR" "$run_path_again"
assert_dir_exists "run dir still exists after re-init" "$RUN_DIR"

echo ""

# ---------- hive_get_task_status ----------
echo "--- hive_get_task_status ---"

# Status: running (file does not exist)
status=$(hive_get_task_status "$RUN_DIR/tasks/task-99.result.md")
assert_eq "missing result file returns running" "running" "$status"

# Status: complete
echo "HIVE_TASK_COMPLETE" > "$RUN_DIR/tasks/task-gs-1.result.md"
status=$(hive_get_task_status "$RUN_DIR/tasks/task-gs-1.result.md")
assert_eq "HIVE_TASK_COMPLETE marker returns complete" "complete" "$status"

# Status: complete via integration marker
echo "HIVE_INTEGRATION_COMPLETE" > "$RUN_DIR/tasks/task-gs-2.result.md"
status=$(hive_get_task_status "$RUN_DIR/tasks/task-gs-2.result.md")
assert_eq "HIVE_INTEGRATION_COMPLETE marker returns complete" "complete" "$status"

# Status: error
echo "HIVE_TASK_ERROR" > "$RUN_DIR/tasks/task-gs-3.result.md"
status=$(hive_get_task_status "$RUN_DIR/tasks/task-gs-3.result.md")
assert_eq "HIVE_TASK_ERROR marker returns error" "error" "$status"

# Status: context_heavy
echo "HIVE_TASK_CONTEXT_HEAVY" > "$RUN_DIR/tasks/task-gs-4.result.md"
status=$(hive_get_task_status "$RUN_DIR/tasks/task-gs-4.result.md")
assert_eq "HIVE_TASK_CONTEXT_HEAVY marker returns context_heavy" "context_heavy" "$status"

# Status: running (file exists but no marker yet)
echo "Still working..." > "$RUN_DIR/tasks/task-gs-5.result.md"
status=$(hive_get_task_status "$RUN_DIR/tasks/task-gs-5.result.md")
assert_eq "result file without marker returns running" "running" "$status"

echo ""

# ---------- hive_get_task_progress ----------
echo "--- hive_get_task_progress ---"

# No progress file -> empty
progress=$(hive_get_task_progress "$RUN_DIR" "99")
assert_eq "missing progress file returns empty" "" "$progress"

# Progress file with entries -> last line without timestamp
printf '[10:00:01] Starting\n[10:00:05] Writing tests\n[10:00:30] Done\n' \
  > "$RUN_DIR/tasks/task-gp-1.progress.txt"
progress=$(hive_get_task_progress "$RUN_DIR" "gp-1")
assert_eq "returns last line without timestamp" "Done" "$progress"

# Single entry
printf '[09:59:01] Initializing\n' > "$RUN_DIR/tasks/task-gp-2.progress.txt"
progress=$(hive_get_task_progress "$RUN_DIR" "gp-2")
assert_eq "single entry without timestamp" "Initializing" "$progress"

echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
