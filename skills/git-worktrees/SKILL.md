---
name: git-worktrees
description: "Manage git worktrees for Hive worker isolation — creation, workflow, merge, and cleanup"
---

# Git Worktrees

## Overview

Git worktrees are the isolation mechanism for Hive workers. Each worker gets its own worktree with a dedicated branch, ensuring zero conflicts during parallel execution. Workers commit changes to their branch, and the orchestrator merges branches back sequentially after completion. This skill covers the full worktree lifecycle: creation, worker workflow, merge, conflict resolution, and cleanup. All operations use functions from `lib/worktree-manager.sh`.

## What Worktrees Provide

| Benefit | How |
|---------|-----|
| Isolated working copy | Each worker has its own directory with a full checkout |
| Zero conflicts during execution | Workers modify different copies of the same files |
| Controlled merge | Orchestrator decides when and in what order to merge |
| Parallel safety | Multiple Claude Code instances can run simultaneously |
| Clean rollback | If a worker fails, its branch is simply discarded |

## Creating Worktrees

Use `hive_worktree_create` from `lib/worktree-manager.sh`:

```bash
source lib/worktree-manager.sh

WORKTREE_PATH=$(hive_worktree_create "$REPO_PATH" "$RUN_ID" "$TASK_NUMBER")
# Result: .hive/worktrees/task-<N>/
# Branch: hive/<run-id>/task-<N>
```

This creates:
- A new directory at `.hive/worktrees/task-<N>/` containing a full checkout
- A new branch `hive/<run-id>/task-<N>` based on the current HEAD
- The worktree is ready for the worker to use immediately

### Directory Structure

```
.hive/
  worktrees/
    task-1/          # Worker 1's isolated checkout
    task-2/          # Worker 2's isolated checkout
    task-3/          # Worker 3's isolated checkout
    integration-batch-1/  # Integration worker's checkout
  runs/
    <run-id>/
      tasks/         # Result files
      context/       # Shared context
      status.json    # Run state
      log.md         # Event log
```

### Integration Worktrees

Integration workers also use worktrees, with a different naming convention:

```bash
git worktree add ".hive/worktrees/integration-batch-$BATCH_NUM" \
  -b "hive/$RUN_ID/integration-batch-$BATCH_NUM"
```

Integration worktrees are created after all batch tasks are merged, so they contain the combined output of the batch.

## Worker Workflow

Every worker follows this exact sequence:

### 1. Receive Worktree Path

The orchestrator passes the worktree path to the worker via the task prompt. The worker must work exclusively in this directory.

### 2. Work in the Worktree

The worker performs all file operations inside its worktree:

- Read and modify source files
- Create new files
- Run tests (from within the worktree)
- Install dependencies if needed

**Critical rule**: a worker must NEVER modify files outside its assigned worktree. No touching the main repo, no touching other worktrees.

### 3. Commit Changes

Before marking the task complete, the worker must commit all changes:

```bash
cd "$WORKTREE_PATH"
git add -A
git commit -m "hive: task-$TASK_NUMBER — <description>"
```

Uncommitted changes will be lost during cleanup. The commit is the worker's deliverable.

### 4. Write Result File

After committing, the worker writes its result to the run directory (NOT the worktree):

```
.hive/runs/<run-id>/tasks/task-<N>.result.md
```

The result file must contain:
- `HIVE_TASK_COMPLETE` marker (or `HIVE_TASK_ERROR` on failure)
- Summary of what was done
- List of files modified
- Test results

### 5. Exit

The worker exits. It does not merge, does not clean up its worktree, does not touch other tasks. The orchestrator handles everything after this point.

## Merge Process

The orchestrator merges worker branches back into the working branch after all tasks in a batch complete.

### Sequential Merge Order

Merge in task number order within each batch:

```bash
source lib/worktree-manager.sh

# Batch 1 tasks: [1, 2, 3]
hive_worktree_merge "$REPO_PATH" "$RUN_ID" 1
hive_worktree_merge "$REPO_PATH" "$RUN_ID" 2
hive_worktree_merge "$REPO_PATH" "$RUN_ID" 3
```

Each call runs:
```bash
git merge "hive/$RUN_ID/task-$N" --no-edit -m "hive: merge task-$N from run $RUN_ID"
```

Sequential order ensures deterministic results, easier conflict detection per task, and simple rollback.

## Conflict Resolution

When `hive_worktree_merge` exits non-zero, a merge conflict occurred.

### Detection

```bash
if ! hive_worktree_merge "$REPO_PATH" "$RUN_ID" "$TASK_NUMBER"; then
  # Merge conflict detected
  CONFLICTING_FILES=$(git -C "$REPO_PATH" diff --name-only --diff-filter=U)
  hive_log_event "$RUN_DIR" "CONFLICT: task-$TASK_NUMBER conflicts on: $CONFLICTING_FILES"
fi
```

### Resolution Options

**Option A: Dispatch resolution worker**
1. Create a resolution worktree or use the current state
2. Dispatch a Sonnet or Opus worker with the conflict details
3. Worker resolves conflicts, commits, marks complete
4. Resume merge sequence

**Option B: Ask user**
1. Report conflicting files to the user
2. Wait for manual resolution
3. User commits the resolution
4. Resume merge sequence

**Option C: Abort and replan**
1. Reset the merge (`git merge --abort`)
2. Flag the conflicting tasks
3. Suggest replanning to avoid the conflict (different file boundaries)

Choose Option A for straightforward conflicts (e.g., import ordering). Choose Option B for semantic conflicts in business logic. Choose Option C if the plan itself is flawed.

## Cleanup

After a run completes successfully, clean up all worktrees and branches:

```bash
source lib/worktree-manager.sh

hive_worktree_cleanup_run "$REPO_PATH" "$RUN_ID"
```

This removes:
- All worktree directories under `.hive/worktrees/`
- All branches matching `hive/<run-id>/*`
- The `.hive/worktrees/` directory itself

Do NOT clean up if the run failed, if merge conflicts are unresolved, or if the user requests preservation. Failed worktrees are evidence for debugging.

Use `hive_worktree_list "$REPO_PATH"` to see all active Hive worktrees before starting a new run.

## Key Principles

- **Worktrees enforce isolation.** No worker touches another worker's files. This is the foundation of parallel execution.
- **Branches are the deliverable.** Workers commit to their branch; the orchestrator merges. Clean separation of concerns.
- **Sequential merge is non-negotiable.** Parallel merges cause corruption. Always merge in task order.
- **Preserve on failure.** Worktrees are evidence. Never clean up a failed run automatically.
- **All operations through `lib/worktree-manager.sh`.** Use the provided functions, not raw git commands, to ensure consistent naming and paths.
