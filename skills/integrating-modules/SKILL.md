---
name: integrating-modules
description: "Connect independently-built modules after batch completion using integration workers"
---

# Integrating Modules

## Overview

After a batch of parallel workers completes, their outputs exist in separate worktrees as isolated modules. Integration connects these modules into a working whole. An integration worker receives the merged codebase, writes wiring code and integration tests, and verifies the modules work together. This skill guides the orchestrator through the integration phase.

## When to Integrate

Integration is triggered when any task in a completed batch has `integration_required: true` in the plan. Check this with `hive_get_integration_tasks()` from `lib/plan-parser.sh`.

If no tasks in the batch require integration, skip directly to the next batch or the merge phase.

## Integration Process

Follow these steps in order after all tasks in a batch reach `HIVE_TASK_COMPLETE`:

### Step 1: Merge All Batch Worktrees

Merge each worker branch back into the working branch sequentially, in task order:

```bash
source lib/worktree-manager.sh

# For each task N in the batch (in order):
hive_worktree_merge "$REPO_PATH" "$RUN_ID" "$TASK_NUMBER"
```

If any merge produces conflicts, stop and handle them before continuing (see Failure Handling below).

### Step 2: Create Integration Worktree

Create a dedicated worktree for the integration worker:

```bash
# Integration worktree path: .hive/worktrees/integration-batch-<N>/
git worktree add ".hive/worktrees/integration-batch-$BATCH_NUM" \
  -b "hive/$RUN_ID/integration-batch-$BATCH_NUM"
```

### Step 3: Select Integration Worker Model

The integration worker must use a model equal to or higher than the most capable model in the batch:

```bash
source lib/plan-parser.sh
MAX_MODEL=$(hive_get_batch_max_model "$PLAN_FILE" "$BATCH_NUM")
```

This ensures the integration worker can reason at the level of the most complex module it is connecting.

### Step 4: Dispatch Integration Worker

The integration worker receives:

- **Worktree path**: `.hive/worktrees/integration-batch-<N>/`
- **Module list**: which tasks were built and what each one produced
- **Integration prompt**: from the plan (task metadata field `integration_prompt`)
- **Access to merged codebase**: all batch modules already merged into the integration branch

The worker's job:
1. Read the modules that were built in the batch
2. Write wiring code that connects them (imports, event handlers, API calls, shared state)
3. Write integration tests that verify the modules work together
4. Ensure all existing tests still pass
5. Write a result file marking `HIVE_INTEGRATION_COMPLETE`

### Step 5: Verify Integration

After the integration worker completes:

1. Check result file for `HIVE_INTEGRATION_COMPLETE` marker
2. Run the full test suite in the integration worktree
3. If tests pass, merge the integration branch back to working branch
4. Clean up the integration worktree

## Integration Worker Receives

Provide this context to the integration worker via the system prompt and task prompt:

| Context | Source |
|---------|--------|
| List of modules built | Parsed from batch task results in `.hive/runs/<run-id>/tasks/` |
| Integration prompt | From plan task metadata (`integration_prompt` field) |
| Full merged codebase | The integration worktree contains all merged code |
| Project conventions | CLAUDE.md and project-specific rules (loaded automatically) |

## Integration Worker Creates

The integration worker must produce:

1. **Wiring code** — imports, dependency injection, event bus subscriptions, API client setup, route registration, or whatever connects the modules
2. **Integration tests** — tests that exercise the boundary between modules (API contract tests, event flow tests, shared state consistency checks)
3. **API contracts** — if modules communicate via API, ensure request/response types are aligned and exported from a shared location
4. **Result file** — `.hive/runs/<run-id>/tasks/integration-batch-<N>.result.md` containing `HIVE_INTEGRATION_COMPLETE` and a summary of what was connected

## Common Integration Patterns

### Shared Types
Modules that share data structures need a common types file. The integration worker creates or updates `src/types/shared.ts` (or equivalent) with types both modules import.

### Event Bus
When module A emits events that module B consumes, the integration worker wires the event subscriptions and ensures event payloads match expected types.

### API Clients
If one module exposes an API and another calls it, the integration worker generates a typed client or verifies the existing client matches the API contract.

### Database Relations
When modules create related database entities (e.g., User and Order), the integration worker adds foreign keys, updates Prisma schema relations, and writes migration files.

### Route Registration
For web applications, the integration worker registers new routes/pages in the application router and verifies navigation paths.

## Failure Handling

### Merge Conflicts

If `hive_worktree_merge` fails with conflicts:

1. Log the conflicting files in `.hive/runs/<run-id>/log.md`
2. Report the conflict list to the orchestrator
3. Dispatch a conflict-resolution worker (use Sonnet or Opus) with the conflict details
4. The resolution worker fixes conflicts, commits, and marks resolution complete
5. Resume the merge sequence

### Integration Test Failures

If the integration worker's tests fail:

1. Read the test failure output from the result file
2. Dispatch a fix task with model Sonnet or Opus
3. The fix worker receives: failing test output, integration code, module code
4. After fix, re-run the full test suite
5. If fix fails twice, mark as BLOCKED and alert orchestrator

### Worker Failure

If the integration worker itself errors (writes `HIVE_TASK_ERROR`):

1. Follow the standard escalation policy (retry same model, then upgrade tier)
2. If Opus fails, mark integration as BLOCKED
3. Log all failure details for manual debugging

## Key Principles

- **Integrate only when needed.** Skip integration if no tasks in the batch have `integration_required: true`.
- **Merge before integrating.** The integration worker needs the full merged codebase, not individual worktrees.
- **Model ceiling rule.** Integration worker model >= highest model in the batch. Use `hive_get_batch_max_model()`.
- **Tests are the gate.** Integration is not complete until integration tests AND existing tests pass.
- **Isolation still applies.** The integration worker operates in its own worktree, not on the main branch.
- **Sequential merge order.** Merge worktrees in task number order within the batch to maintain deterministic results.
