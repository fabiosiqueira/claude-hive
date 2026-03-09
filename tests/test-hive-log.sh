#!/usr/bin/env bash
# Tests for lib/hive-log.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

source "$LIB_DIR/hive-log.sh"

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

assert_contains() {
  local description="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected to contain: $needle"
    echo "    actual:   $haystack"
    ((FAIL++))
  fi
}

# --- Tests ---

echo "=== hive-log.sh tests ==="
echo ""

echo "--- hive_log function exists ---"
assert_success "hive_log function exists" type hive_log

echo ""
echo "--- INFO level ---"
output_info=$(hive_log INFO "test info message" 2>&1)
assert_contains "hive_log INFO includes [INFO]" "$output_info" "[INFO]"
assert_contains "hive_log INFO includes message" "$output_info" "test info message"

echo ""
echo "--- WARN level ---"
output_warn=$(hive_log WARN "test warn message" 2>&1)
assert_contains "hive_log WARN includes [WARN]" "$output_warn" "[WARN]"
assert_contains "hive_log WARN includes message" "$output_warn" "test warn message"

echo ""
echo "--- ERROR level ---"
output_error=$(hive_log ERROR "test error message" 2>&1)
assert_contains "hive_log ERROR includes [ERROR]" "$output_error" "[ERROR]"
assert_contains "hive_log ERROR includes message" "$output_error" "test error message"

echo ""
echo "--- Output goes to stderr ---"
# Capture stdout and stderr separately
stdout_capture=$(hive_log INFO "to stderr" 2>/dev/null)
stderr_capture=$(hive_log INFO "to stderr" 2>&1 1>/dev/null)
if [[ -z "$stdout_capture" && -n "$stderr_capture" ]]; then
  echo "  PASS: hive_log outputs to stderr, not stdout"
  ((PASS++))
else
  echo "  FAIL: hive_log outputs to stderr, not stdout"
  echo "    stdout: '$stdout_capture'"
  echo "    stderr: '$stderr_capture'"
  ((FAIL++))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
