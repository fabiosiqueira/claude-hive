#!/usr/bin/env bash
# Tests for lib/hive-indent.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

source "$LIB_DIR/hive-indent.sh"

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

# --- Tests ---

echo "=== hive-indent.sh tests ==="
echo ""

echo "--- hive_indent function ---"
assert_success "hive_indent function exists" type hive_indent

echo ""
echo "--- Single line indentation ---"
result=$(hive_indent "hello" "  ")
expected="  hello"
assert_eq "indent single line with spaces" "$expected" "$result"

result=$(hive_indent "test" ">> ")
expected=">> test"
assert_eq "indent single line with custom prefix" "$expected" "$result"

echo ""
echo "--- Multiple lines indentation ---"
multiline_text="line1
line2
line3"
result=$(hive_indent "$multiline_text" "  ")
expected="  line1
  line2
  line3"
assert_eq "indent multiple lines" "$expected" "$result"

multiline_text="first
second"
result=$(hive_indent "$multiline_text" "| ")
expected="| first
| second"
assert_eq "indent multiple lines with pipe prefix" "$expected" "$result"

echo ""
echo "--- Empty text ---"
result=$(hive_indent "" "  ")
assert_eq "indent empty text" "" "$result"

echo ""
echo "--- Empty prefix ---"
result=$(hive_indent "hello" "")
expected="hello"
assert_eq "indent with empty prefix" "$expected" "$result"

multiline_text="line1
line2"
result=$(hive_indent "$multiline_text" "")
expected="line1
line2"
assert_eq "indent multiple lines with empty prefix" "$expected" "$result"

echo ""
echo "--- Special prefixes ---"
result=$(hive_indent "text" ">>>")
expected=">>>text"
assert_eq "indent with multi-char prefix" "$expected" "$result"

result=$(hive_indent "data" "[INFO] ")
expected="[INFO] data"
assert_eq "indent with bracketed prefix" "$expected" "$result"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
