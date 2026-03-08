---
description: "Create a model-tagged implementation plan with batches, dependencies, and complexity routing."
disable-model-invocation: true
---

# /hive-plan -- Model-Tagged Plan Generator

You are creating a structured implementation plan for parallel execution by Hive workers.

## Step 1: Gather Context

Read silently before asking the user anything:
- `CLAUDE.md` at project root for architecture, conventions, and constraints
- `docs/plans/` for existing plans and design documents
- `MEMORY.md` for prior decisions and active project state
- Recent commits (`git log --oneline -10`) to understand current momentum

## Step 2: Roadmap Ingestion

If `docs/roadmap.md` exists:
1. Read the roadmap and extract features/milestones
2. Transform each feature into Hive plan format with model tags and batches
3. After the plan is saved (Step 6), delete `docs/roadmap.md`
4. Update any references to the roadmap in other project files

If no roadmap exists, proceed to Step 3.

## Step 3: Clarify Requirements

If the feature/task is not already clear from the design document or user message:
- Ask the user to describe what needs to be built
- Ask focused, multiple-choice questions to resolve ambiguities
- Stop when you have enough clarity to break down into tasks (typically 2-4 questions)

If a design document already exists in `docs/plans/`, use it as the source of truth.

## Step 4: Generate Plan

Invoke the `hive:writing-plans` skill to create a structured plan with:

- **Model tags**: `[Haiku]`, `[Sonnet]`, `[Opus]` assigned by task complexity
- **Complexity tags**: `[simple]`, `[moderate]`, `[complex]` as batch sizing metadata
- **Batches**: grouped by dependency graph, tasks within a batch run in parallel
- **Integration requirements**: cross-task wiring prompts where modules must connect
- **Acceptance criteria**: observable, testable outcomes for every task

Follow the model assignment heuristics from the skill:
- `[Haiku]` for schema, CRUD, boilerplate, config, renames
- `[Sonnet]` for business logic, APIs, test suites, service layers
- `[Opus]` for architecture, security-critical code, complex algorithms

When uncertain between two tiers, assign the higher one.

## Step 5: Present for Approval

Show the complete plan to the user with:
- Total task count and model distribution (e.g., "12 tasks: 4 Haiku, 6 Sonnet, 2 Opus")
- Batch count and estimated parallelism
- Any integration points between batches
- Highlight any `[Opus]` tasks that might be reducible to `[Sonnet]`

Wait for explicit approval before saving.

## Step 6: Save Plan

Save the approved plan to `docs/plans/YYYY-MM-DD-<feature>.md`. If roadmap ingestion happened in Step 2, delete `docs/roadmap.md` now.

Inform the user: "Plan approved and saved. Ready to dispatch workers with `/hive-dispatch`."

## Gate

The plan is ready when:
- Every task has a model tag and complexity tag
- Every task has exact file paths (no "update relevant files")
- Every task has acceptance criteria
- Dependencies form a valid DAG (no cycles)
- Batch boundaries respect all dependency constraints
