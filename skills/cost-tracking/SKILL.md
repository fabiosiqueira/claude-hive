---
name: cost-tracking
description: "Estimate, track, and report costs across Hive worker sessions to control spend"
---

# Cost Tracking

## Overview

Every Hive run has a cost. Model routing decisions directly impact spend, and without tracking, costs can escalate silently — especially with Opus workers. This skill covers pre-dispatch cost estimation, per-worker budget caps, post-run reporting, and optimization strategies. The goal is predictable, controlled spend on every run.

## Cost Per Model

Reference costs per million tokens (MTok). Use these for all estimations:

| Tier | Input Cost | Output Cost |
|------|-----------|-------------|
| Haiku | $0.25/MTok | $1.25/MTok |
| Sonnet | $3.00/MTok | $15.00/MTok |
| Opus | $15.00/MTok | $75.00/MTok |

Key ratio: one Opus task costs roughly the same as 60 Haiku tasks. Model routing is the single biggest lever for cost control.

## Token Estimation Heuristics

Estimate token usage based on task complexity tags from the plan:

| Complexity | Estimated Input | Estimated Output | Total Tokens |
|------------|----------------|-----------------|--------------|
| `[simple]` | ~2,000 | ~1,500 | ~3,500 |
| `[moderate]` | ~6,000 | ~6,000 | ~12,000 |
| `[complex]` | ~18,000 | ~25,000 | ~43,000 |

These are conservative estimates. Actual usage varies by task scope, codebase size in context, and number of tool calls the worker makes.

### Adjustment Factors

Apply these multipliers when conditions differ from the baseline:

| Condition | Multiplier | Reason |
|-----------|-----------|--------|
| Large codebase context | 1.5x input | More files loaded into context |
| TDD cycle (write test + implement) | 1.3x total | Multiple rounds of generation |
| Escalation retry | 1.0x additional per retry | Full re-run at same or higher tier |
| Integration worker | 1.5x total | Reads multiple modules, writes wiring code |

## Pre-Dispatch Estimation

Before dispatching a batch, calculate the expected cost:

### Per-Task Estimate

```
task_cost = (input_tokens * input_rate) + (output_tokens * output_rate)
```

Example for a `[moderate]` Sonnet task:
```
input:  6,000 tokens * ($3.00 / 1,000,000) = $0.018
output: 6,000 tokens * ($15.00 / 1,000,000) = $0.090
task_cost = $0.108
```

### Batch Estimate

Sum all task estimates in the batch:

```
batch_cost = sum(task_cost for each task in batch)
```

### Run Estimate

Sum all batch estimates plus integration workers:

```
run_cost = sum(batch_cost for each batch) + sum(integration_worker_cost for each batch with integration)
```

### Estimation Table Format

Present estimates to the user before dispatch:

```
| Task | Model  | Complexity | Est. Input | Est. Output | Est. Cost |
|------|--------|------------|-----------|-------------|-----------|
| 1    | Haiku  | simple     | 2,000     | 1,500       | $0.002    |
| 2    | Haiku  | simple     | 2,000     | 1,500       | $0.002    |
| 3    | Sonnet | moderate   | 6,000     | 6,000       | $0.108    |
| 4    | Opus   | complex    | 18,000    | 25,000      | $2.145    |
|      |        |            |           | **Total**   | **$2.257**|
```

## Budget Allocation

### Per-Worker Budget Cap

Use the `--max-budget-usd` flag when launching each worker via `hive_build_claude_command()` from `lib/tmux-manager.sh`:

| Complexity | Suggested Budget Cap |
|------------|---------------------|
| `[simple]` Haiku | $0.05 |
| `[moderate]` Sonnet | $0.50 |
| `[complex]` Opus | $5.00 |
| Integration worker | $2.00 - $5.00 (based on batch complexity) |

These caps prevent any single worker from consuming disproportionate resources. If a worker hits its budget limit, it stops — this is better than unbounded spend.

### Run-Level Budget

Before starting a run, estimate the total cost and compare against a threshold. Warn the user if:

- Estimated total exceeds $10 (or a configured threshold)
- Any single task estimates above $5
- The run contains more than 3 Opus tasks

```
WARNING: Estimated run cost is $14.50 (3 Opus tasks, 5 Sonnet, 8 Haiku).
Proceed? [y/n]
```

## Post-Run Reporting

After a run completes, generate a cost report. If Claude Code provides session cost data in worker output, use it. Otherwise, fall back to estimates.

### Report Format

Write the cost report to `.hive/runs/<run-id>/cost-report.md`:

```markdown
# Cost Report — Run <run-id>

## Summary
- **Total estimated cost**: $X.XX
- **Tasks executed**: N
- **Escalations**: N (additional cost: $X.XX)
- **Model distribution**: Haiku: N, Sonnet: N, Opus: N

## Per-Task Breakdown

| Task | Model | Complexity | Est. Cost | Escalated | Notes |
|------|-------|------------|-----------|-----------|-------|
| 1    | Haiku | simple     | $0.002    | No        |       |
| 3    | Sonnet| moderate   | $0.108    | Yes (->Opus) | Failed first attempt |

## Optimization Notes
- [Any observations about tasks that could have used a cheaper model]
- [Any tasks that escalated unnecessarily]
```

## Cost Optimization Strategies

### 1. Batch Simple Tasks for Haiku

Group mechanical tasks together in the same batch. Haiku handles high volume at negligible cost. A batch of 10 Haiku tasks costs less than one Sonnet task.

### 2. Limit Opus to the Critical Path

Opus is 60x more expensive than Haiku. Only use it for tasks that genuinely require deep architectural reasoning, security analysis, or complex debugging. When in doubt, assign Sonnet and let escalation handle the rare failures.

### 3. Keep Task Scope Tight

A well-scoped 2-5 minute task uses fewer tokens than a sprawling multi-file task. Granular plans produce cheaper runs because workers load less context and generate more focused output.

### 4. Review Escalation Patterns

If tasks frequently escalate from Haiku to Sonnet, the plan may be under-specifying task requirements. Improve task descriptions rather than accepting repeated escalation costs.

### 5. Avoid Unnecessary Context

Workers should receive only the context they need. The system prompt and task prompt should reference specific files, not dump the entire codebase. Smaller context windows mean fewer input tokens.

### 6. Use Integration Workers Judiciously

Not every batch needs integration. Only dispatch integration workers when tasks have `integration_required: true`. Unnecessary integration workers waste Sonnet/Opus budget on no-op wiring.

## Budget Alerts

During a run, the orchestrator should flag these conditions:

| Condition | Alert Level | Action |
|-----------|------------|--------|
| Single task estimated > $5 | Warning | Confirm with user before dispatch |
| Total run estimated > $10 | Warning | Show cost table, ask for confirmation |
| Escalation adds > 50% to batch cost | Info | Log in cost report, note for optimization |
| Worker hits budget cap | Error | Worker stops, log the event, decide retry or abort |

## Key Principles

- **Estimate before dispatch.** Never start a run without knowing the expected cost.
- **Budget cap every worker.** Use `--max-budget-usd` on every `claude` invocation. No unbounded workers.
- **Cheapest model that works.** Every Opus task should have a justification. Default to Sonnet for ambiguous cases.
- **Track escalation cost separately.** Escalations are hidden costs — make them visible in the report.
- **Cost report is mandatory.** Every completed run gets a cost report in `.hive/runs/<run-id>/cost-report.md`.
- **Warn early, not late.** Flag expensive runs before dispatch, not after the money is spent.
