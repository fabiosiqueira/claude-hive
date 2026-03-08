#!/usr/bin/env bash
# Tests for lib/worktree-manager.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0

source "$LIB_DIR/worktree-manager.sh"

# Create a temporary git repo for testing
TEST_REPO=$(mktemp -d)
TEST_RUN_ID="test-run-$$"

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

cleanup() {
  cd /tmp
  # Remove worktrees before deleting repo
  git -C "$TEST_REPO" worktree list --porcelain 2>/dev/null | grep "^worktree " | while read -r _ path; do
    if [[ "$path" != "$TEST_REPO" ]]; then
      git -C "$TEST_REPO" worktree remove --force "$path" 2>/dev/null || true
    fi
  done
  rm -rf "$TEST_REPO"
}
trap cleanup EXIT

# Setup test repo
setup_test_repo() {
  cd "$TEST_REPO"
  git init -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -m "initial commit"
}

# --- Tests ---

echo "=== worktree-manager.sh tests ==="
echo ""

setup_test_repo

echo "--- hive_worktree_create ---"
wt_path=$(hive_worktree_create "$TEST_REPO" "$TEST_RUN_ID" "1")
assert_eq "returns worktree path" "$TEST_REPO/.hive/worktrees/task-1" "$wt_path"
assert_eq "worktree dir exists" "true" "$([ -d "$wt_path" ] && echo true || echo false)"
assert_eq "file.txt exists in worktree" "true" "$([ -f "$wt_path/file.txt" ] && echo true || echo false)"

# Check branch was created
branch_exists=$(git -C "$TEST_REPO" branch --list "hive/$TEST_RUN_ID/task-1" | wc -l | tr -d ' ')
assert_eq "branch created" "1" "$branch_exists"

echo ""
echo "--- hive_worktree_create second worker ---"
wt_path_2=$(hive_worktree_create "$TEST_REPO" "$TEST_RUN_ID" "2")
assert_eq "second worktree created" "true" "$([ -d "$wt_path_2" ] && echo true || echo false)"

echo ""
echo "--- hive_worktree_list ---"
wt_list=$(hive_worktree_list "$TEST_REPO")
if echo "$wt_list" | grep -q "task-1"; then
  echo "  PASS: list includes task-1"
  ((PASS++))
else
  echo "  FAIL: list missing task-1"
  ((FAIL++))
fi
if echo "$wt_list" | grep -q "task-2"; then
  echo "  PASS: list includes task-2"
  ((PASS++))
else
  echo "  FAIL: list missing task-2"
  ((FAIL++))
fi

echo ""
echo "--- hive_worktree_remove ---"
assert_success "removes worktree" hive_worktree_remove "$TEST_REPO" "$TEST_RUN_ID" "1"
assert_eq "worktree dir removed" "false" "$([ -d "$wt_path" ] && echo true || echo false)"

# Check branch was deleted
branch_exists_after=$(git -C "$TEST_REPO" branch --list "hive/$TEST_RUN_ID/task-1" | wc -l | tr -d ' ')
assert_eq "branch deleted" "0" "$branch_exists_after"

echo ""
echo "--- hive_worktree_cleanup_run ---"
# Create a few more worktrees
hive_worktree_create "$TEST_REPO" "$TEST_RUN_ID" "3" >/dev/null
hive_worktree_create "$TEST_REPO" "$TEST_RUN_ID" "4" >/dev/null
assert_success "cleans up all worktrees for run" hive_worktree_cleanup_run "$TEST_REPO" "$TEST_RUN_ID"

remaining=$(git -C "$TEST_REPO" worktree list --porcelain | grep -c "hive" || true)
assert_eq "no hive worktrees remain" "0" "$remaining"

echo ""
echo "--- hive_worktree_merge ---"
# Create a worktree, make changes, then merge
merge_wt=$(hive_worktree_create "$TEST_REPO" "merge-test" "1")
cd "$merge_wt"
echo "new content" > new-file.txt
git add new-file.txt
git commit -m "add new file from worker"
cd "$TEST_REPO"

assert_success "merges worktree branch" hive_worktree_merge "$TEST_REPO" "merge-test" "1"
assert_eq "merged file exists on main" "true" "$([ -f "$TEST_REPO/new-file.txt" ] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
