#!/usr/bin/env bash
# Tests for lib/plan-parser.sh
# Note: set -e is NOT used here because we need to test failure cases
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

source "$LIB_DIR/plan-parser.sh" 2>/dev/null || true

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
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected to contain: $needle"
    echo "    actual:   $haystack"
    ((FAIL++))
  fi
}

assert_line_count() {
  local description="$1"
  local expected="$2"
  local input="$3"
  local actual
  if [[ -z "$input" ]]; then
    actual=0
  else
    actual=$(echo "$input" | wc -l | tr -d ' ')
  fi
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected line count: $expected"
    echo "    actual line count:   $actual"
    ((FAIL++))
  fi
}

# --- Setup: create temp plan files ---

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Standard plan with multiple batches
PLAN_FILE="$TEMP_DIR/plan.md"
cat > "$PLAN_FILE" << 'PLAN_EOF'
# Feature Plan: User Management

## Batch 1

### Task 1: [Sonnet] [moderate] Create user authentication module
- **Depends on:** none
- **Files:** src/auth/login.ts, src/auth/register.ts
- **Integration required:** true
- **Integration prompt:** "Users and Auth modules are implemented. Create the session management integration."

### Task 2: [Haiku] [simple] Create database schema for users
- **Depends on:** none
- **Files:** prisma/schema.prisma
- **Integration required:** false

## Batch 2

### Task 3: [Opus] [complex] Design API gateway architecture
- **Depends on:** 1, 2
- **Files:** src/gateway/router.ts, src/gateway/middleware.ts
- **Integration required:** false

### Task 4: [Sonnet] [moderate] Implement rate limiting middleware
- **Depends on:** 3
- **Files:** src/gateway/rate-limiter.ts
- **Integration required:** true
- **Integration prompt:** "Gateway and rate limiter are done. Wire them together."

## Batch 3

### Task 5: [Haiku] [simple] Add health check endpoint
- **Depends on:** 3
- **Files:** src/gateway/health.ts
- **Integration required:** false
PLAN_EOF

# Empty plan file
EMPTY_PLAN="$TEMP_DIR/empty.md"
cat > "$EMPTY_PLAN" << 'EMPTY_EOF'
# Empty Plan

No tasks here.
EMPTY_EOF

# Plan with missing fields
SPARSE_PLAN="$TEMP_DIR/sparse.md"
cat > "$SPARSE_PLAN" << 'SPARSE_EOF'
## Batch 1

### Task 1: [Sonnet] [moderate] Task with minimal fields
- **Depends on:** none
- **Files:** src/main.ts
SPARSE_EOF

# --- Tests ---

echo "=== plan-parser.sh tests ==="
echo ""

# --- hive_parse_plan ---

echo "--- hive_parse_plan ---"

result=$(hive_parse_plan "$PLAN_FILE")

assert_line_count "parses all 5 tasks" "5" "$result"

line1=$(echo "$result" | sed -n '1p')
assert_eq "task 1 number" "1" "$(echo "$line1" | cut -d'|' -f1)"
assert_eq "task 1 batch" "1" "$(echo "$line1" | cut -d'|' -f2)"
assert_eq "task 1 model" "sonnet" "$(echo "$line1" | cut -d'|' -f3)"
assert_eq "task 1 complexity" "moderate" "$(echo "$line1" | cut -d'|' -f4)"
assert_eq "task 1 description" "Create user authentication module" "$(echo "$line1" | cut -d'|' -f5)"
assert_eq "task 1 depends" "none" "$(echo "$line1" | cut -d'|' -f6)"
assert_eq "task 1 integration required" "true" "$(echo "$line1" | cut -d'|' -f7)"
assert_contains "task 1 integration prompt" "session management integration" "$(echo "$line1" | cut -d'|' -f8)"

line2=$(echo "$result" | sed -n '2p')
assert_eq "task 2 number" "2" "$(echo "$line2" | cut -d'|' -f1)"
assert_eq "task 2 model" "haiku" "$(echo "$line2" | cut -d'|' -f3)"
assert_eq "task 2 complexity" "simple" "$(echo "$line2" | cut -d'|' -f4)"
assert_eq "task 2 description" "Create database schema for users" "$(echo "$line2" | cut -d'|' -f5)"
assert_eq "task 2 integration required" "false" "$(echo "$line2" | cut -d'|' -f7)"
assert_eq "task 2 integration prompt empty" "" "$(echo "$line2" | cut -d'|' -f8)"

line3=$(echo "$result" | sed -n '3p')
assert_eq "task 3 batch is 2" "2" "$(echo "$line3" | cut -d'|' -f2)"
assert_eq "task 3 model" "opus" "$(echo "$line3" | cut -d'|' -f3)"
assert_eq "task 3 complexity" "complex" "$(echo "$line3" | cut -d'|' -f4)"
assert_eq "task 3 depends" "1, 2" "$(echo "$line3" | cut -d'|' -f6)"

line5=$(echo "$result" | sed -n '5p')
assert_eq "task 5 batch is 3" "3" "$(echo "$line5" | cut -d'|' -f2)"
assert_eq "task 5 description" "Add health check endpoint" "$(echo "$line5" | cut -d'|' -f5)"

echo ""
echo "--- hive_parse_plan edge cases ---"

empty_result=$(hive_parse_plan "$EMPTY_PLAN")
assert_eq "empty plan returns empty" "" "$empty_result"

nonexistent_result=$(hive_parse_plan "$TEMP_DIR/nonexistent.md" 2>/dev/null)
assert_eq "nonexistent file returns empty" "" "$nonexistent_result"

sparse_result=$(hive_parse_plan "$SPARSE_PLAN")
assert_line_count "sparse plan parses 1 task" "1" "$sparse_result"
sparse_line=$(echo "$sparse_result" | sed -n '1p')
assert_eq "sparse task integration default false" "false" "$(echo "$sparse_line" | cut -d'|' -f7)"
assert_eq "sparse task integration prompt empty" "" "$(echo "$sparse_line" | cut -d'|' -f8)"

# --- hive_get_batch_tasks ---

echo ""
echo "--- hive_get_batch_tasks ---"

batch1=$(hive_get_batch_tasks "$PLAN_FILE" 1)
assert_line_count "batch 1 has 2 tasks" "2" "$batch1"
assert_contains "batch 1 contains task 1" "1|1|sonnet" "$batch1"
assert_contains "batch 1 contains task 2" "2|1|haiku" "$batch1"

batch2=$(hive_get_batch_tasks "$PLAN_FILE" 2)
assert_line_count "batch 2 has 2 tasks" "2" "$batch2"
assert_contains "batch 2 contains task 3" "3|2|opus" "$batch2"
assert_contains "batch 2 contains task 4" "4|2|sonnet" "$batch2"

batch3=$(hive_get_batch_tasks "$PLAN_FILE" 3)
assert_line_count "batch 3 has 1 task" "1" "$batch3"

batch99=$(hive_get_batch_tasks "$PLAN_FILE" 99)
assert_eq "nonexistent batch returns empty" "" "$batch99"

# --- hive_get_batch_count ---

echo ""
echo "--- hive_get_batch_count ---"

count=$(hive_get_batch_count "$PLAN_FILE")
assert_eq "standard plan has 3 batches" "3" "$count"

empty_count=$(hive_get_batch_count "$EMPTY_PLAN")
assert_eq "empty plan has 0 batches" "0" "$empty_count"

sparse_count=$(hive_get_batch_count "$SPARSE_PLAN")
assert_eq "sparse plan has 1 batch" "1" "$sparse_count"

# --- hive_get_task_model ---

echo ""
echo "--- hive_get_task_model ---"

model1=$(hive_get_task_model "$PLAN_FILE" 1)
assert_eq "task 1 model is sonnet" "sonnet" "$model1"

model2=$(hive_get_task_model "$PLAN_FILE" 2)
assert_eq "task 2 model is haiku" "haiku" "$model2"

model3=$(hive_get_task_model "$PLAN_FILE" 3)
assert_eq "task 3 model is opus" "opus" "$model3"

model99=$(hive_get_task_model "$PLAN_FILE" 99)
assert_eq "nonexistent task model is empty" "" "$model99"

# --- hive_get_integration_tasks ---

echo ""
echo "--- hive_get_integration_tasks ---"

int_batch1=$(hive_get_integration_tasks "$PLAN_FILE" 1)
assert_line_count "batch 1 has 1 integration task" "1" "$int_batch1"
assert_contains "batch 1 integration is task 1" "1|1|sonnet" "$int_batch1"

int_batch2=$(hive_get_integration_tasks "$PLAN_FILE" 2)
assert_line_count "batch 2 has 1 integration task" "1" "$int_batch2"
assert_contains "batch 2 integration is task 4" "4|2|sonnet" "$int_batch2"

int_batch3=$(hive_get_integration_tasks "$PLAN_FILE" 3)
assert_eq "batch 3 has no integration tasks" "" "$int_batch3"

# --- hive_get_batch_max_model ---

echo ""
echo "--- hive_get_batch_max_model ---"

max1=$(hive_get_batch_max_model "$PLAN_FILE" 1)
assert_eq "batch 1 max model is sonnet (sonnet > haiku)" "sonnet" "$max1"

max2=$(hive_get_batch_max_model "$PLAN_FILE" 2)
assert_eq "batch 2 max model is opus (opus > sonnet)" "opus" "$max2"

max3=$(hive_get_batch_max_model "$PLAN_FILE" 3)
assert_eq "batch 3 max model is haiku (only haiku)" "haiku" "$max3"

max99=$(hive_get_batch_max_model "$PLAN_FILE" 99)
assert_eq "nonexistent batch max model is empty" "" "$max99"

# --- Results ---

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
