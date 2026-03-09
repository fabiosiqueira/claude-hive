#!/usr/bin/env bash
# Tests for lib/hive-colors.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

source "$LIB_DIR/hive-colors.sh"

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

echo "=== hive-colors.sh tests ==="
echo ""

echo "--- Color constants ---"
assert_eq "HIVE_COLOR_RED defined" "true" "$([[ -n "${HIVE_COLOR_RED:-}" ]] && echo true || echo false)"
assert_eq "HIVE_COLOR_GREEN defined" "true" "$([[ -n "${HIVE_COLOR_GREEN:-}" ]] && echo true || echo false)"
assert_eq "HIVE_COLOR_YELLOW defined" "true" "$([[ -n "${HIVE_COLOR_YELLOW:-}" ]] && echo true || echo false)"
assert_eq "HIVE_COLOR_BLUE defined" "true" "$([[ -n "${HIVE_COLOR_BLUE:-}" ]] && echo true || echo false)"
assert_eq "HIVE_COLOR_RESET defined" "true" "$([[ -n "${HIVE_COLOR_RESET:-}" ]] && echo true || echo false)"

echo ""
echo "--- hive_colorize function ---"
assert_success "hive_colorize function exists" type hive_colorize

output=$(hive_colorize "31" "test text")
assert_contains "hive_colorize outputs text" "$output" "test text"
assert_contains "hive_colorize applies color code" "$output" "31"
# Check reset is in output (HIVE_COLOR_RESET contains ESC char which shell will render)
if echo "$output" | grep -q "0m"; then
  echo "  PASS: hive_colorize includes reset"
  ((PASS++))
else
  echo "  FAIL: hive_colorize includes reset"
  ((FAIL++))
fi

echo ""
echo "--- hive_print_status function ---"
assert_success "hive_print_status function exists" type hive_print_status

# Test 'ok' status
status_ok=$(hive_print_status "ok" "everything is fine")
if echo "$status_ok" | grep -q "32m"; then
  echo "  PASS: hive_print_status 'ok' includes GREEN"
  ((PASS++))
else
  echo "  FAIL: hive_print_status 'ok' includes GREEN"
  ((FAIL++))
fi
assert_contains "hive_print_status 'ok' includes message" "$status_ok" "everything is fine"

# Test 'error' status
status_error=$(hive_print_status "error" "something broke")
if echo "$status_error" | grep -q "31m"; then
  echo "  PASS: hive_print_status 'error' includes RED"
  ((PASS++))
else
  echo "  FAIL: hive_print_status 'error' includes RED"
  ((FAIL++))
fi
assert_contains "hive_print_status 'error' includes message" "$status_error" "something broke"

# Test 'warn' status
status_warn=$(hive_print_status "warn" "be careful")
if echo "$status_warn" | grep -q "33m"; then
  echo "  PASS: hive_print_status 'warn' includes YELLOW"
  ((PASS++))
else
  echo "  FAIL: hive_print_status 'warn' includes YELLOW"
  ((FAIL++))
fi
assert_contains "hive_print_status 'warn' includes message" "$status_warn" "be careful"

# Test 'info' status
status_info=$(hive_print_status "info" "fyi this is info")
if echo "$status_info" | grep -q "34m"; then
  echo "  PASS: hive_print_status 'info' includes BLUE"
  ((PASS++))
else
  echo "  FAIL: hive_print_status 'info' includes BLUE"
  ((FAIL++))
fi
assert_contains "hive_print_status 'info' includes message" "$status_info" "fyi this is info"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
