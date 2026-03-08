#!/usr/bin/env bash
# Hive worktree-manager.sh — Git worktree operations for worker isolation
# Usage: source this file to get hive_worktree_* functions

readonly HIVE_WORKTREE_DIR=".hive/worktrees"

# Create a worktree for a worker task
# Args: repo_path, run_id, task_number
# Returns: path to the created worktree
hive_worktree_create() {
  local repo_path="$1"
  local run_id="$2"
  local task_number="$3"
  local branch_name="hive/$run_id/task-$task_number"
  local worktree_path="$repo_path/$HIVE_WORKTREE_DIR/task-$task_number"

  mkdir -p "$(dirname "$worktree_path")"
  git -C "$repo_path" worktree add "$worktree_path" -b "$branch_name" >/dev/null 2>&1

  echo "$worktree_path"
}

# List all hive worktrees for a repo
# Args: repo_path
hive_worktree_list() {
  local repo_path="$1"

  git -C "$repo_path" worktree list --porcelain | grep -A2 "hive" | grep "^worktree " | sed 's/^worktree //'
}

# Remove a specific worktree and its branch
# Args: repo_path, run_id, task_number
hive_worktree_remove() {
  local repo_path="$1"
  local run_id="$2"
  local task_number="$3"
  local branch_name="hive/$run_id/task-$task_number"
  local worktree_path="$repo_path/$HIVE_WORKTREE_DIR/task-$task_number"

  git -C "$repo_path" worktree remove --force "$worktree_path" 2>/dev/null || true
  git -C "$repo_path" branch -D "$branch_name" 2>/dev/null || true
}

# Clean up all worktrees for a specific run
# Args: repo_path, run_id
hive_worktree_cleanup_run() {
  local repo_path="$1"
  local run_id="$2"

  # Remove only worktrees belonging to this run (match by branch name)
  local run_branches
  run_branches=$(git -C "$repo_path" branch --list "hive/$run_id/*" 2>/dev/null | tr -d ' *')

  git -C "$repo_path" worktree list --porcelain | grep "^worktree " | sed 's/^worktree //' | while read -r wt_path; do
    if echo "$wt_path" | grep -q "$HIVE_WORKTREE_DIR"; then
      # Only remove if worktree belongs to a branch from this run
      local wt_branch
      wt_branch=$(git -C "$repo_path" worktree list --porcelain | grep -A1 "^worktree $wt_path$" | grep "^branch " | sed 's|^branch refs/heads/||')
      if echo "$run_branches" | grep -qF "$wt_branch" 2>/dev/null; then
        git -C "$repo_path" worktree remove --force "$wt_path" 2>/dev/null || true
      fi
    fi
  done

  # Remove all branches for this run
  git -C "$repo_path" branch --list "hive/$run_id/*" | while read -r branch; do
    branch=$(echo "$branch" | tr -d ' *')
    git -C "$repo_path" branch -D "$branch" 2>/dev/null || true
  done

  # Clean up the worktrees directory
  rm -rf "$repo_path/$HIVE_WORKTREE_DIR" 2>/dev/null || true
}

# Merge a worker's branch back into the current branch
# Args: repo_path, run_id, task_number
hive_worktree_merge() {
  local repo_path="$1"
  local run_id="$2"
  local task_number="$3"
  local branch_name="hive/$run_id/task-$task_number"

  git -C "$repo_path" merge "$branch_name" --no-edit -m "hive: merge task-$task_number from run $run_id"
}
