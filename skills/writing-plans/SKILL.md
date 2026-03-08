---
name: writing-plans
description: "Create implementation plans with model tags, complexity levels, and dependency graphs"
---

# Writing Plans

## Overview

This skill transforms an approved design document into a structured implementation plan. The plan defines every task, assigns it a model tier, organizes tasks into parallel batches, and maps dependencies. The plan is the contract between the orchestrator and the workers — nothing is built that is not in the plan.

Use this skill after brainstorming produces an approved design, or when the user directly requests `/hive-plan`.

## Plan Format

Plans are saved to `docs/plans/YYYY-MM-DD-<feature>.md` and follow this structure:

```markdown
# Plan: <Feature Name>

**Design**: docs/plans/YYYY-MM-DD-<topic>-design.md
**Created**: YYYY-MM-DD
**Status**: draft | approved | in-progress | completed

## Summary
One paragraph describing what this plan builds.

## Batch 1: <Batch Description>

### Task 1: [Haiku] [simple] Create database schema for users
- **Files**: src/db/schema/users.ts, prisma/schema.prisma
- **Depends on**: none
- **Integration required**: no
- **Acceptance**: Schema compiles, migration runs, types generated

### Task 2: [Sonnet] [moderate] Implement user registration API
- **Files**: src/api/routes/auth/register.ts, src/services/auth.ts
- **Depends on**: none
- **Integration required**: yes
- **Integration prompt**: "Wire registration endpoint to user schema. Verify types match between API input validation and Prisma model."
- **Acceptance**: Tests pass for valid registration, duplicate email, invalid input

## Batch 2: <Batch Description>
...
```

## Task Anatomy

Every task must include:

| Field | Required | Description |
|-------|----------|-------------|
| Model tag | Yes | `[Haiku]`, `[Sonnet]`, or `[Opus]` |
| Complexity tag | Yes | `[simple]`, `[moderate]`, or `[complex]` |
| Description | Yes | One sentence — what the worker must produce |
| Files | Yes | Exact file paths that will be created or modified |
| Depends on | Yes | Task IDs this task requires, or "none" |
| Integration required | Yes | Whether an integration worker runs after the batch |
| Integration prompt | If integration | Instructions for connecting this task's output with others |
| Acceptance | Yes | Observable criteria — tests pass, endpoint responds, file exists |

## Model Assignment Heuristics

| Model | Assign When |
|-------|-------------|
| `[Haiku]` | Schema definitions, Prisma models, CRUD endpoints, boilerplate files, config, renames, simple tests |
| `[Sonnet]` | Business logic, API endpoints with validation, test suites, data transformations, service layers, moderate refactors |
| `[Opus]` | Architecture decisions, security-critical code, complex algorithms, cross-cutting concerns, system design, performance optimization |

When uncertain between two tiers, assign the higher one. Under-assignment causes failures; over-assignment only costs slightly more.

## Complexity Tags

Tags serve as metadata for batch sizing and future model routing:

- `[simple]` — Mechanical tasks. A worker can do 3-5 simple tasks in one batch without confusion.
- `[moderate]` — Requires reading and understanding existing code. One task per worker is typical.
- `[complex]` — Requires reasoning about architecture, trade-offs, or multiple interacting systems. Always one task per worker, always `[Opus]`.

## Dependency Graph Rules

- Tasks within the same batch have **no dependencies on each other** and run in parallel
- Batches are sequential — Batch N+1 starts only after Batch N is fully complete (including integration)
- If Task 5 depends on Task 2, Task 5 must be in a later batch than Task 2
- Minimize batch count — more parallelism means faster execution
- If two tasks touch the same file, they must be in different batches (later one depends on earlier)

## Integration Tasks

When multiple tasks in a batch produce modules that must communicate:

1. Set `Integration required: yes` on each task that participates
2. Write an `Integration prompt` describing how the modules connect
3. After the batch completes, the orchestrator dispatches an integration worker (always `[Sonnet]` minimum)
4. The integration worker merges worktrees and wires modules together
5. Integration tests run before proceeding to the next batch

## Roadmap Ingestion

If `docs/roadmap.md` exists in the project:

1. Read the roadmap and extract features/milestones
2. Transform each feature into Hive plan format with proper model tags and batches
3. Save the plan to `docs/plans/YYYY-MM-DD-<feature>.md`
4. Delete the original `docs/roadmap.md`
5. Update any references to the roadmap in other docs

This converts informal roadmaps into executable Hive plans.

## Process

1. Read the approved design document from `docs/plans/`
2. Break the design into tasks of 2-5 minutes each
3. Assign model tags and complexity tags to each task
4. Organize tasks into batches respecting dependency constraints
5. Add integration prompts where cross-task wiring is needed
6. Define acceptance criteria for every task
7. Present the plan to the user for review
8. Revise based on feedback
9. Save the approved plan to `docs/plans/YYYY-MM-DD-<feature>.md`

## When NOT to Use Hive

Hive adds setup overhead (worktree creation, merge, cleanup) per batch. For small or
ambiguous tasks, this overhead exceeds the benefit. Use the main session directly when:

| Scenario | Why Hive doesn't help |
|----------|----------------------|
| Task < 5 minutes | Worktree setup + merge takes longer than the task itself |
| Debugging with unknown root cause | Worker reads files randomly; you need interactive exploration |
| Task touches 3+ deeply interdependent files | Worker likely exhausts turns on context loading; use Opus directly in main session |
| Single-file change | No parallelism benefit; use Edit directly |
| Exploratory spike / proof of concept | Scope undefined; Hive plan would be wrong before first worker finishes |

**Rule of thumb:** if you're not sure what files need to change, don't dispatch workers yet.
Use the main session to investigate, then write a Hive plan once the scope is clear.

## Hard Gates

- **Every task must have a model tag.** No untagged tasks.
- **Every task must have exact file paths.** No "update relevant files".
- **Every task must have acceptance criteria.** No "implement feature X" without observable outcome.
- **No circular dependencies.** The dependency graph must be a DAG.
- **Batch boundaries must respect dependencies.** A task cannot depend on something in its own batch.

## Key Principles

- **Granularity prevents failure.** A 2-minute task is easy to retry; a 30-minute task wastes resources on failure.
- **Model tags are cost controls.** Haiku costs a fraction of Opus. Route accurately.
- **Dependencies are the critical path.** Fewer batches means faster completion. Maximize parallelism.
- **Acceptance criteria are worker contracts.** Workers know exactly when they are done.
- **Plans are living documents.** Update the plan when reality diverges during execution.
- **After approval, transition to dispatching-workers.** The plan is ready for `/hive-dispatch`.
