#!/usr/bin/env bash
# Tests for lib/tmux-manager.sh
# Note: set -e is NOT used here because we need to test failure cases
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0
TEST_SESSION="hive-test-$$"

# Source without inheriting set -e
(
  set +e
  source "$LIB_DIR/tmux-manager.sh" 2>/dev/null
)
source "$LIB_DIR/tmux-manager.sh" 2>/dev/null || true

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

assert_success() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description (command failed: $*)"
    ((FAIL++))
  fi
}

assert_fail() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL: $description (expected failure but succeeded)"
    ((FAIL++))
  else
    echo "  PASS: $description"
    ((PASS++))
  fi
}

cleanup() {
  tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
}
trap cleanup EXIT

# --- Tests ---

echo "=== tmux-manager.sh tests ==="
echo ""

echo "--- hive_check_tmux ---"
assert_success "tmux is available" hive_check_tmux

echo ""
echo "--- hive_create_session ---"
assert_success "creates tmux session" hive_create_session "$TEST_SESSION"

has_session=0
tmux has-session -t "$TEST_SESSION" 2>/dev/null && has_session=1
assert_eq "session exists" "1" "$has_session"

assert_fail "fails on duplicate session" hive_create_session "$TEST_SESSION"

echo ""
echo "--- hive_create_worker ---"
assert_success "creates worker window" hive_create_worker "$TEST_SESSION" "worker-1" "/tmp"
local_windows=$(tmux list-windows -t "$TEST_SESSION" -F "#{window_name}" | grep -c "worker-1" || echo "0")
assert_eq "worker window exists" "1" "$local_windows"

echo ""
echo "--- hive_capture_output ---"
tmux send-keys -t "$TEST_SESSION:worker-1" "echo HIVE_TEST_MARKER" Enter
sleep 1
captured=$(hive_capture_output "$TEST_SESSION" "worker-1" 10)
if echo "$captured" | grep -q "HIVE_TEST_MARKER"; then
  echo "  PASS: captures output containing marker"
  ((PASS++))
else
  echo "  FAIL: marker not found in captured output"
  ((FAIL++))
fi

echo ""
echo "--- hive_check_worker_alive ---"
alive=$(hive_check_worker_alive "$TEST_SESSION" "worker-1")
assert_eq "worker is alive" "true" "$alive"

echo ""
echo "--- hive_kill_worker ---"
assert_success "kills worker window" hive_kill_worker "$TEST_SESSION" "worker-1"
local_windows_after=$(tmux list-windows -t "$TEST_SESSION" -F "#{window_name}" 2>/dev/null | grep -c "worker-1" 2>/dev/null || true)
assert_eq "worker window removed" "0" "$local_windows_after"

echo ""
echo "--- hive_kill_session ---"
assert_success "kills session" hive_kill_session "$TEST_SESSION"
has_session_after=0
tmux has-session -t "$TEST_SESSION" 2>/dev/null && has_session_after=1
assert_eq "session gone" "0" "$has_session_after"

echo ""
echo "--- hive_launch_worker ---"
hive_create_session "$TEST_SESSION"
hive_create_worker "$TEST_SESSION" "worker-launch" "/tmp"
assert_success "launches worker with command" hive_launch_worker "$TEST_SESSION" "worker-launch" "echo LAUNCHED"
sleep 1
launched_output=$(hive_capture_output "$TEST_SESSION" "worker-launch" 5)
if echo "$launched_output" | grep -q "LAUNCHED"; then
  echo "  PASS: launch command executed"
  ((PASS++))
else
  echo "  FAIL: launch command not executed"
  ((FAIL++))
fi

echo ""
echo "--- hive_build_claude_command ---"
cmd=$(hive_build_claude_command "haiku" "" "" "")
if echo "$cmd" | grep -q "\-\-model 'haiku'"; then
  echo "  PASS: command includes model flag"
  ((PASS++))
else
  echo "  FAIL: command missing model flag"
  ((FAIL++))
fi

if echo "$cmd" | grep -q "\-\-dangerously-skip-permissions"; then
  echo "  PASS: command includes skip-permissions"
  ((PASS++))
else
  echo "  FAIL: command missing skip-permissions"
  ((FAIL++))
fi

cmd_with_budget=$(hive_build_claude_command "sonnet" "" "5.00" "do stuff")
if echo "$cmd_with_budget" | grep -q "\-\-max-budget-usd '5.00'"; then
  echo "  PASS: command includes budget flag"
  ((PASS++))
else
  echo "  FAIL: command missing budget flag"
  ((FAIL++))
fi

echo ""
echo "--- hive_build_claude_command with signal ---"
cmd_with_signal=$(hive_build_claude_command "sonnet" "" "" "do stuff" "hive-abc-task-1-done")
if echo "$cmd_with_signal" | grep -q "tmux wait-for -S 'hive-abc-task-1-done'"; then
  echo "  PASS: command includes wait-for signal"
  ((PASS++))
else
  echo "  FAIL: command missing wait-for signal"
  ((FAIL++))
fi

cmd_no_signal=$(hive_build_claude_command "haiku" "" "" "do stuff" "")
if echo "$cmd_no_signal" | grep -q "wait-for"; then
  echo "  FAIL: command should not include wait-for without signal"
  ((FAIL++))
else
  echo "  PASS: command without signal has no wait-for"
  ((PASS++))
fi

echo ""
echo "--- hive_signal_channel ---"
channel=$(hive_signal_channel "run123" "5")
assert_eq "signal channel format" "hive-run123-task-5-done" "$channel"

echo ""
echo "--- hive_wait_for_worker (background signal test) ---"
# Signal in background, then wait — should return immediately
tmux wait-for -S "hive-test-signal-$$" &
sleep 0.1
hive_wait_for_worker "hive-test-signal-$$"
echo "  PASS: wait-for returned after signal"
((PASS++))

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
