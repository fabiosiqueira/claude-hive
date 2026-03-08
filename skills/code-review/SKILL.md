---
name: code-review
description: "Request and perform code reviews with structured evaluation"
---

# Code Review

## Overview

This skill covers both sides of code review: requesting reviews for your changes and performing reviews on code. The goal is to catch bugs, security issues, and quality problems before code reaches production. Reviews are technical evaluations, not rubber stamps.

Use this skill when changes are ready for review, when dispatching a review agent, or when evaluating code submitted by a worker agent.

## Requesting a Review

### Prepare the Review Context

Before requesting a review, assemble:

1. **The diff**: All changed files with enough surrounding context to understand the changes
2. **The why**: A clear explanation of what changed and the reason behind it
3. **Related tests**: Test files that cover the changed behavior
4. **Architectural constraints**: Any design decisions, patterns, or invariants the reviewer needs to know
5. **Areas of concern**: Specific parts where you want extra scrutiny

### Structure the Review Request

```
## Changes
<brief summary of what changed>

## Motivation
<why this change was made>

## Areas of concern
<specific questions or uncertain decisions>

## Files changed
<list of modified files with brief description of each>

## How to verify
<steps to test the changes>
```

### Dispatch a Review Agent

When dispatching a subagent for code review:

1. Provide the full diff as context
2. Include the project's CLAUDE.md or relevant style/architecture rules
3. Specify the review checklist (see below)
4. Request structured output: issue severity, file, line, description, suggestion

## Performing a Review

### The Review Checklist

Evaluate every change against these categories, in priority order:

**Correctness (must-fix)**
- [ ] Does the code do what it claims to do?
- [ ] Are there logic errors, off-by-one mistakes, or race conditions?
- [ ] Are all error paths handled? What happens when things fail?
- [ ] Are assumptions about input data validated?
- [ ] Does the code handle null, undefined, empty, and boundary cases?

**Security (must-fix)**
- [ ] Is user input validated and sanitized at system boundaries?
- [ ] Are secrets kept out of source code and logs?
- [ ] Is authentication checked before authorization?
- [ ] Are SQL queries parameterized (or using Prisma safely)?
- [ ] Is output properly encoded to prevent XSS?
- [ ] Are there any new attack surfaces introduced?

**Test Coverage (must-fix)**
- [ ] Do tests exist for the new behavior?
- [ ] Were tests written BEFORE implementation (TDD)?
- [ ] Are edge cases covered?
- [ ] Do tests verify failure modes, not just happy paths?
- [ ] Are test assertions specific (not just "does not throw")?

**Performance (should-fix)**
- [ ] Are there unnecessary database queries or N+1 problems?
- [ ] Are large datasets processed efficiently?
- [ ] Are there blocking operations in async contexts?
- [ ] Is memoization used where appropriate?
- [ ] Could any operation time out or hang?

**Readability (should-fix)**
- [ ] Are function and variable names descriptive?
- [ ] Is the code self-documenting or does it need comments?
- [ ] Are functions small enough (under 50 lines)?
- [ ] Is nesting depth reasonable (under 4 levels)?
- [ ] Is there unnecessary complexity?

**Style and Conventions (could-fix)**
- [ ] Does the code follow the project's style guide?
- [ ] Are imports organized correctly?
- [ ] Are magic numbers replaced with named constants?
- [ ] Is immutability respected (no mutation of inputs)?
- [ ] TypeScript: no `any`, explicit return types on public functions?

### Classify Review Findings

Every issue found gets a severity:

| Severity | Meaning | Action Required |
|----------|---------|----------------|
| **must-fix** | Bug, security vulnerability, data loss risk, missing test | Block merge until resolved |
| **should-fix** | Performance issue, readability concern, missing edge case | Fix before merge if reasonable, otherwise create follow-up |
| **could-fix** | Style preference, minor naming improvement, optional optimization | Author decides — not a blocker |

### Structure Review Output

For each finding:

```
[SEVERITY] file:line — Description
  Context: what the code does
  Issue: what is wrong or risky
  Suggestion: specific improvement (with code if helpful)
```

## Receiving Review Feedback

### Evaluate Technically

1. Read each finding carefully — understand the concern before responding
2. Distinguish between valid technical issues and stylistic preferences
3. Check if the finding applies to the current context (reviewers sometimes miss context)

### Respond to Each Finding

For every review comment, respond with one of:

- **Fixed**: Applied the suggestion, describe what changed
- **Addressed differently**: Fixed the issue but with a different approach, explain why
- **Won't fix**: The finding does not apply or the tradeoff is intentional, provide rationale
- **Needs discussion**: The issue is real but the solution is not clear, propose alternatives

### After Review

1. Apply all must-fix items
2. Apply should-fix items where the effort is reasonable
3. Track any deferred items as follow-up tasks
4. Re-run verification after applying review changes
5. Request re-review if substantial changes were made

## Review Scope Rules

- **Focus on changed code** — do not review unrelated files or suggest unrelated improvements
- **Review the diff, not the whole file** — unless the change affects the file's overall structure
- **One concern per finding** — do not bundle multiple issues into a single comment
- **Be specific** — "this could be better" is not actionable; explain what and how
- **Provide context** — if the suggestion requires knowledge the author might not have, explain it
