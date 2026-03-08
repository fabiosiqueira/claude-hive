---
name: model-routing
description: "Heuristics for selecting the optimal model tier for each task based on complexity, cost, and reliability"
---

# Model Routing

## Overview

Model routing determines which Claude model tier handles each task in a Hive plan. The goal is to minimize cost while maintaining quality: cheap models for mechanical work, capable models for hard problems. This skill is referenced during plan creation (`/hive-plan`) and dispatch (`/hive-dispatch`).

## Model Tiers

Hive uses three model tiers. Each maps to a specific Claude model:

| Tier | Model ID | Strengths |
|------|----------|-----------|
| Haiku | claude-haiku-4-5 | Fast, cheap, reliable for well-scoped mechanical tasks |
| Sonnet | claude-sonnet-4-6 | Balanced cost/capability, handles most business logic |
| Opus | claude-opus-4-6 | Most capable, required for architecture and complex reasoning |

## Cost Table

Costs are per million tokens (MTok). Every routing decision is a cost decision.

| Tier | Input Cost | Output Cost | Relative Cost |
|------|-----------|-------------|---------------|
| Haiku | ~$0.25/MTok | ~$1.25/MTok | 1x (baseline) |
| Sonnet | ~$3.00/MTok | ~$15.00/MTok | ~12x Haiku |
| Opus | ~$15.00/MTok | ~$75.00/MTok | ~60x Haiku |

## Assignment Rules

Route each task to the lowest tier that can reliably complete it.

### Haiku Tasks

Assign to Haiku when the task is mechanical and well-defined:

- Schema definitions (Prisma models, Zod schemas, TypeScript types)
- CRUD operations with clear input/output
- Boilerplate generation (config files, project scaffolding)
- Renaming and refactoring with explicit scope
- Simple unit tests for pure functions
- Documentation updates with provided content
- Environment variable setup and validation
- Copy/move/delete file operations with exact paths

### Sonnet Tasks

Assign to Sonnet when the task requires understanding context but not deep reasoning:

- Business logic implementation from clear specifications
- API endpoint handlers with defined request/response contracts
- Moderate test suites (integration tests, edge cases)
- Data transformation pipelines
- Database queries with joins and aggregations
- Frontend components with state management
- Error handling and validation logic
- Module wiring that follows established patterns

### Opus Tasks

Assign to Opus when the task requires architectural judgment or deep analysis:

- Architecture design and system-level decisions
- Security-critical code (auth, encryption, access control)
- Complex algorithms (optimization, concurrency, distributed systems)
- System integration across multiple services or domains
- Debugging complex issues with unclear root cause
- Performance optimization requiring profiling analysis
- Migration strategies across breaking changes
- Integration workers that connect multiple independently-built modules
- Tasks requiring context loading across 3+ interdependent modules before implementation

## Escalation Policy

When a worker fails at its assigned tier, follow this escalation chain:

```
Step 1: Retry with same model (once)
        - Same task prompt, same worktree, fresh session
        - Check result file for HIVE_TASK_COMPLETE

Step 2: Upgrade to next tier
        - Haiku failure  -> retry with Sonnet
        - Sonnet failure -> retry with Opus

Step 3: If Opus fails -> mark task BLOCKED
        - Write HIVE_TASK_ERROR to result file
        - Log failure details in .hive/runs/<run-id>/log.md
        - Halt the current batch
        - Alert orchestrator for manual intervention
```

Do not skip tiers. The escalation must be sequential to keep costs controlled.

### Context Overload Escalation (HIVE_TASK_CONTEXT_HEAVY)

This is a separate escalation path — triggered when a worker self-signals context overload
**before** exhausting its turns. It is NOT a task failure; it is an early exit with a diagnosis.

```
On HIVE_TASK_CONTEXT_HEAVY:

  Do NOT retry with same model — context depth is model-independent at lower tiers.
  Do NOT follow the standard escalation chain (Step 1 → 2 → 3).

  Read the worker's "Recommended split" from the result file.

  Option A — Split (preferred when recommended split is clear):
    1. Create Task A: [Haiku] [simple] "Summarize interaction between X, Y, Z"
       - Output: task-<N>.context-summary.md in the run context dir
    2. Create Task B: [<original tier or Opus>] "Implement using summary from Task A"
       - Depends on: Task A
    These replace the original task. Original worktree can be reused for Task B.

  Option B — Upgrade to Opus (when split is unclear or modules are too coupled to separate):
    1. Re-dispatch the same task with [Opus] and --max-turns 200
    2. Pass the worker's "Blocking dependency chain" as additional context in the task prompt
       so Opus does not repeat the same reads from scratch
```

Use Option A by default. Option B only when the worker's result indicates the modules
cannot be meaningfully summarized before implementation.

## Context Depth Signals

Some tasks require reading 3+ interconnected modules before any implementation can begin.
This "context loading phase" consumes turns disproportionately — a Sonnet worker may exhaust
its turn limit just reading dependencies (A → B → C) without writing a single line.

**Detect deep-context tasks during planning by these markers:**
- Task description mentions 3+ modules that interact with each other
- Task involves debugging with unclear root cause across files
- Task requires understanding how an existing system works before changing it
- Files listed span 3+ layers (e.g., agent → logic → engine → tests)

**Rule: if a task is deep-context AND assigned to Sonnet → upgrade to Opus.**

Opus handles context accumulation better and is less likely to stall on reads.
Also raise `--max-turns` to 200 for these tasks.

**Alternative: split into two tasks:**
1. `[Haiku]` `[simple]` "Read and summarize the interaction between A, B, C" → writes a summary file
2. `[Sonnet]` `[moderate]` "Implement fix using summary in task N" → reads summary, implements

This splits context loading from implementation, letting each worker stay within bounds.

## Budget Estimation

Estimate token usage per task complexity tag before dispatch:

| Complexity | Estimated Input | Estimated Output | Total Tokens |
|------------|----------------|-----------------|--------------|
| `[simple]` | ~1,500 tokens | ~1,000 tokens | ~2,500 |
| `[moderate]` | ~5,000 tokens | ~5,000 tokens | ~10,000 |
| `[complex]` | ~15,000 tokens | ~20,000 tokens | ~35,000 |

To estimate batch cost:
1. Count tasks per model tier in the batch
2. Multiply task count by estimated tokens for complexity
3. Apply model cost rates from the cost table
4. Sum across all tasks in the batch

Use `--max-turns` flag per worker to cap runaway execution (Haiku=30, Sonnet=80, Opus=150). Nunca use `--max-budget-usd` — incompatível com Claude Max.

## Cost Optimization Tips

1. **Batch simple tasks for Haiku.** Group mechanical tasks together. Haiku handles volume well and the cost is negligible.
2. **Reserve Opus for the critical path.** Only tasks that genuinely need deep reasoning should use Opus. When in doubt, start with Sonnet.
3. **Keep task scope tight.** A focused 2-5 minute task uses fewer tokens than a sprawling one. Granular plans save money.
4. **Avoid unnecessary escalation.** If a Haiku task fails due to a bad prompt (not model limitation), fix the prompt before escalating.
5. **Use Sonnet as default for ambiguous tasks.** When complexity is unclear, Sonnet is the safe middle ground.

## Integration Worker Model Selection

Integration workers that connect modules from a batch must use a model equal to or higher than the most capable model used in that batch:

```
Batch models: [Haiku, Haiku, Sonnet] -> Integration worker: Sonnet
Batch models: [Sonnet, Opus]         -> Integration worker: Opus
Batch models: [Haiku, Haiku]         -> Integration worker: Haiku
```

Use `hive_get_batch_max_model()` from `lib/plan-parser.sh` to determine this automatically.

## Key Principles

- **Cheapest model that works.** Never use Opus for work Haiku can handle. Cost scales 60x.
- **Escalation is a signal.** Frequent escalation means tasks are under-specified or mis-tagged.
- **Turn limit is a hard constraint.** Set `--max-turns` on every worker. No unbounded runs.
- **Complexity tags drive routing.** The `[simple]`, `[moderate]`, `[complex]` tags in the plan map directly to model tiers.
- **Integration workers match the batch ceiling.** They need at least as much capability as the hardest task they are connecting.
- **Deep context = Opus or split.** Tasks that read 3+ interconnected modules before writing anything must use Opus or be split into a read task + write task.
