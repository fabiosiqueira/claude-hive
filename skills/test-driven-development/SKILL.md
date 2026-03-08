---
name: test-driven-development
description: "TDD cycle for implementation tasks — RED, GREEN, REFACTOR"
---

# Test-Driven Development

## Overview

This skill enforces the TDD discipline on every implementation task. No code gets written without a failing test first. No test gets modified to make it pass. The cycle is non-negotiable: write a failing test, write the minimum code to pass it, then clean up while keeping tests green.

Use this skill whenever you are implementing new features, fixing bugs, or refactoring existing code.

## The TDD Cycle

### RED — Write a Failing Test

1. Identify the behavior you need to implement
2. Write a test that describes that behavior precisely
3. Run the test — it MUST fail
4. If the test passes immediately, the test is wrong — rewrite it
5. Confirm the failure is for the RIGHT reason:
   - Expected: assertion failure because the behavior does not exist yet
   - Not acceptable: syntax error, import error, missing file, or wrong test setup
6. Only proceed to GREEN after confirming a legitimate failure

### GREEN — Minimum Implementation

1. Write the absolute minimum code to make the failing test pass
2. No gold-plating — do not add features the test does not require
3. Do not optimize — that comes in REFACTOR
4. Do not handle edge cases unless a test demands it
5. Run the test — it MUST pass now
6. If it does not pass, adjust the implementation (not the test)

### REFACTOR — Clean Up

1. Improve code quality: extract functions, rename variables, remove duplication
2. Run the full test suite after every change — all tests must stay green
3. If a refactor breaks a test, undo the refactor and try a different approach
4. Apply naming conventions, immutability rules, and file size limits from the project style guide
5. Commit when the refactor is clean and all tests pass

## What Gets Tested

### Every Change Starts With a Test

- New feature: test the expected behavior before writing the feature
- Bug fix: write a test that reproduces the bug before fixing it
- Refactor: ensure existing tests cover the behavior before changing the structure

### Test Types and When to Use Them

**Unit tests** — pure functions, utilities, transformations, business logic
- Must be fast: under 10ms per test
- Zero external dependencies — mock everything external (DB, HTTP, filesystem)
- One behavior per test — if the test name has "and", split it

**Integration tests** — API endpoints, database operations, WebSocket handlers
- Use real or test DB when possible (not mocked ORM)
- Test both success paths and meaningful failure modes
- Verify HTTP status codes, response shapes, and headers

**E2E tests** — critical user journeys only
- Reserve for flows that integration tests cannot cover
- Run in CI, not on every save — these are slow by nature

### Coverage Targets

| Code Type                      | Minimum Coverage |
|-------------------------------|-----------------|
| General business logic         | 80% lines/branches |
| Financial calculations         | 100%            |
| Authentication / authorization | 100%            |
| Security-critical paths        | 100%            |

## Edge Cases Checklist

Always include tests for:

- [ ] `null` and `undefined` inputs
- [ ] Empty strings, empty arrays, empty objects
- [ ] Boundary values: minimum, maximum, zero, negative
- [ ] `NaN` and `Infinity` for numeric functions
- [ ] Invalid types passed to typed functions
- [ ] Concurrent access to shared resources
- [ ] Error thrown mid-flow — what state remains?
- [ ] Very large inputs (performance boundary)

## Framework Preferences

- **TypeScript/Node.js**: Vitest (preferred), Jest (acceptable)
- **Rust**: `#[test]` modules + `cargo test`
- **E2E**: Playwright
- **Test database**: separate `DATABASE_URL_TEST` env var

## Hard Rules

1. **NEVER modify a test to make it pass** — fix the implementation instead
2. **NEVER skip the RED step** — if you write code before a failing test, you are not doing TDD
3. **NEVER commit with failing tests** — all tests green before any commit
4. **NEVER use `it.skip` or `test.todo`** in committed code without an issue reference
5. **NEVER leave test doubles (mocks/stubs) that hide real bugs** — mock only external boundaries

## Definition of Done

A task is NOT complete until:

- [ ] All new code has tests written FIRST (RED step happened)
- [ ] All tests pass locally
- [ ] Coverage meets the targets for the code type
- [ ] No tests are skipped or disabled
- [ ] Edge cases from the checklist are covered
- [ ] No debug artifacts remain in test files
