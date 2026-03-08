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

Use `--max-budget-usd` flag per worker to cap runaway costs.

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
- **Budget is a hard constraint.** Set `--max-budget-usd` on every worker. No unbounded runs.
- **Complexity tags drive routing.** The `[simple]`, `[moderate]`, `[complex]` tags in the plan map directly to model tiers.
- **Integration workers match the batch ceiling.** They need at least as much capability as the hardest task they are connecting.
