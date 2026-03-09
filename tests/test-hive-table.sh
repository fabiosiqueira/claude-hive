#!/bin/bash
# Tests for hive_print_table function

set -euo pipefail

source "$(dirname "$0")/../lib/hive-table.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_contains() {
  local output="$1"
  local expected="$2"
  local test_name="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$output" | grep -q "$expected"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
    echo "  Expected to contain: $expected"
    echo "  Got: $output"
  fi
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local test_name="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$actual" == "$expected" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
    echo "  Expected: $expected"
    echo "  Got: $actual"
  fi
}

# Test 1: Simple table with 3 columns
echo "Running tests..."
OUTPUT=$(hive_print_table "Task|Model|Status" "1|claude-haiku-4-5|DONE")
assert_contains "$OUTPUT" "Task" "Should contain header 'Task'"
assert_contains "$OUTPUT" "Model" "Should contain header 'Model'"
assert_contains "$OUTPUT" "Status" "Should contain header 'Status'"
assert_contains "$OUTPUT" "1" "Should contain row data '1'"
assert_contains "$OUTPUT" "DONE" "Should contain row data 'DONE'"

# Test 2: Separator line
assert_contains "$OUTPUT" "^-" "Should contain separator line"

# Test 3: Multiple rows
OUTPUT=$(hive_print_table "ID|Name|Value" "1|alice|100\n2|bob|200")
assert_contains "$OUTPUT" "alice" "Should contain 'alice' from first row"
assert_contains "$OUTPUT" "bob" "Should contain 'bob' from second row"

# Test 4: Column alignment and padding
OUTPUT=$(hive_print_table "Short|VeryLongColumnName|X" "a|b|c")
assert_contains "$OUTPUT" "VeryLongColumnName" "Should handle long column names"
assert_contains "$OUTPUT" "Short" "Should handle short column names"

# Test 5: Output structure - should have header, separator, and rows
OUTPUT=$(hive_print_table "A|B" "1|2")
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
assert_equals "$((LINE_COUNT >= 3))" "1" "Should have at least 3 lines (header, separator, data)"

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"

if [ $TESTS_FAILED -gt 0 ]; then
  echo "FAILED: $TESTS_FAILED tests failed"
  exit 1
fi

exit 0
