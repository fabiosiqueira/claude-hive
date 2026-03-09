---
description: "Full Hive pipeline -- from brainstorm to ship with parallel workers."
disable-model-invocation: true
---

# /hive -- Full Pipeline

You are executing the complete Hive pipeline: brainstorm, plan, design, execute, validate, security, and ship.
Follow each phase in order. Each phase has a quality gate -- if it fails, return to the failed phase.

## Phase 1: Brainstorm

Invoke the `hive:brainstorming` skill to refine requirements with the user.

- Gather project context silently before asking questions
- Ask focused questions to resolve ambiguities
- Propose 2-3 approaches with trade-offs
- Present a complete design and get approval
- Save design to `docs/plans/YYYY-MM-DD-<topic>-design.md`

**Gate:** User approved the design document with goal, scope, technical design, and file structure.

## Phase 2: Plan

Read `commands/hive-plan.md` and follow its instructions.

This creates a model-tagged plan with tasks, batches, dependencies, and acceptance criteria.

**Gate:** Plan saved to `docs/plans/` with every task having model tag, file paths, and acceptance criteria.

## Phase 3: Design (if project has UI)

Ask the user: "Does this project have a visual interface? If yes, I will generate the design system."

If yes, read `commands/design-system.md` and follow its instructions.

**Gate:** `docs/design-spec.md` created with tokens, components, and layouts.

If no UI, skip to Phase 4.

## Phase 4: Execute

Read `commands/hive-dispatch.md` and follow its instructions.

This dispatches parallel workers in tmux sessions with git worktrees, monitors progress, handles failures, merges results, and runs tests after each batch.

**Gate:** All tasks complete, all worktrees merged, tests passing after every batch.

## Phase 5: Validate UX (if project has UI)

Read `commands/validate-ux.md` and follow its instructions.

**Gate:** All interactions tested -- navigation, clicks, forms, responsiveness, basic accessibility.

If no UI, skip to Phase 6.

## Phase 6: Security Review

Read `commands/security-review.md` and follow its instructions.

**Gate:** Zero CRITICAL or HIGH issues. MEDIUM issues documented for later fix.

## Phase 7: Ship

Read `commands/ship.md` and follow its instructions.

**Gate:** Version bumped, CHANGELOG updated, README updated, code pushed, PR created (if applicable).

## Flow Control

- If any gate fails, communicate clearly which gate failed and why
- Return to the failed phase and fix before advancing
- Between phases, give a 1-2 line summary of what was completed
- If context is getting large (many phases completed), suggest starting a new session for remaining phases
- Track overall progress: "Phase N/7: <phase-name>"
