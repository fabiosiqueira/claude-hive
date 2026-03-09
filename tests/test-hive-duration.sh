#!/bin/bash

# Tests for hive_format_duration function
# Run: bash tests/test-hive-duration.sh

set -euo pipefail

# Load the function
source "lib/hive-duration.sh"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

test_count=0
pass_count=0

# Test helper
assert_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"

  test_count=$((test_count + 1))

  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} Test $test_count: $description"
    pass_count=$((pass_count + 1))
  else
    echo -e "${RED}✗${NC} Test $test_count: $description"
    echo "  Expected: $expected"
    echo "  Got: $actual"
  fi
}

# Tests
echo "Running hive_format_duration tests..."
echo

# Basic conversions
assert_equal "00:00:00" "$(hive_format_duration 0)" "0 seconds → 00:00:00"
assert_equal "00:00:01" "$(hive_format_duration 1)" "1 second → 00:00:01"
assert_equal "00:01:00" "$(hive_format_duration 60)" "60 seconds (1 minute) → 00:01:00"
assert_equal "00:01:30" "$(hive_format_duration 90)" "90 seconds → 00:01:30"
assert_equal "01:00:00" "$(hive_format_duration 3600)" "3600 seconds (1 hour) → 01:00:00"
assert_equal "01:30:45" "$(hive_format_duration 5445)" "1h 30m 45s → 01:30:45"

# Edge cases
assert_equal "23:59:59" "$(hive_format_duration 86399)" "23:59:59 (max before day) → 23:59:59"
assert_equal "24:00:00" "$(hive_format_duration 86400)" "86400 seconds (24 hours) → 24:00:00"
assert_equal "99:59:59" "$(hive_format_duration 359999)" "99:59:59 (large duration) → 99:59:59"

# Boundary values
assert_equal "00:00:59" "$(hive_format_duration 59)" "59 seconds → 00:00:59"
assert_equal "00:59:59" "$(hive_format_duration 3599)" "3599 seconds → 00:59:59"

echo
echo "Results: $pass_count / $test_count tests passed"

if [ $pass_count -eq $test_count ]; then
  exit 0
else
  exit 1
fi
