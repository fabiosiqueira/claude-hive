#!/bin/bash

# Test suite for hive_assert function
# Usage: bash tests/test-hive-assert.sh

source lib/hive-assert.sh

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local expected_code="$2"
    shift 2

    TESTS_RUN=$((TESTS_RUN + 1))

    # Capture stderr and exit code
    local stderr_output
    stderr_output=$("$@" 2>&1 >/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq $expected_code ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ $test_name (expected exit code $expected_code, got $exit_code)"
        echo "  stderr: $stderr_output"
    fi
}

# Helper to check stderr output
run_test_with_stderr_check() {
    local test_name="$1"
    local expected_code="$2"
    local expected_stderr="$3"
    shift 3

    TESTS_RUN=$((TESTS_RUN + 1))

    local stderr_output
    stderr_output=$("$@" 2>&1 >/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq $expected_code ]] && [[ "$stderr_output" == *"$expected_stderr"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ $test_name"
        if [[ $exit_code -ne $expected_code ]]; then
            echo "  expected exit code $expected_code, got $exit_code"
        fi
        if [[ "$stderr_output" != *"$expected_stderr"* ]]; then
            echo "  expected stderr containing: $expected_stderr"
            echo "  got: $stderr_output"
        fi
    fi
}

echo "Running hive_assert tests..."
echo ""

# TEST: condition is truthy (non-empty string)
run_test "condition is non-empty string" 0 \
    bash -c 'source lib/hive-assert.sh; hive_assert "true" "error message"'

# TEST: condition is 1 (non-zero)
run_test "condition is 1" 0 \
    bash -c 'source lib/hive-assert.sh; hive_assert 1 "error message"'

# TEST: condition is empty string
run_test "condition is empty string returns error" 1 \
    bash -c 'source lib/hive-assert.sh; hive_assert "" "test failed"'

# TEST: condition is 0 (zero)
run_test "condition is 0 returns error" 1 \
    bash -c 'source lib/hive-assert.sh; hive_assert 0 "test failed"'

# TEST: stderr contains message when condition fails
run_test_with_stderr_check "stderr contains message on failure" 1 "test error message" \
    bash -c 'source lib/hive-assert.sh; hive_assert "" "test error message"'

# TEST: stderr is printed to stderr not stdout
run_test "message goes to stderr" 1 \
    bash -c 'source lib/hive-assert.sh; hive_assert "" "to_stderr" 2>/dev/null'

# TEST: no stderr when condition is truthy
run_test "no stderr on success" 0 \
    bash -c 'source lib/hive-assert.sh; hive_assert 1 "should_not_print" 2>&1 | grep -q "should_not_print" && exit 1 || exit 0'

echo ""
echo "=========================================="
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
