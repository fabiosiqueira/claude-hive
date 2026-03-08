---
name: verification
description: "Verify work is actually complete before declaring done"
---

# Verification

## Overview

This skill ensures that no work is declared complete without running actual verification in the current session. Saying "done" without proof is not acceptable. Every claim of completion must be backed by passing tests, clean builds, and confirmed behavior.

Use this skill as the final step before declaring any task, feature, or fix as complete.

## The Verification Checklist

Run through every item. Do not skip any step. Do not declare done until all applicable items pass.

### 1. Tests Pass

- [ ] Run the project's test command (`npm test`, `vitest run`, `cargo test`, etc.)
- [ ] ALL tests must pass — not just the new ones
- [ ] Zero skipped tests (no `it.skip`, `test.todo`, `#[ignore]` without issue ref)
- [ ] New code has test coverage meeting project targets
- [ ] Edge cases from the TDD checklist are covered

**HARD GATE**: If any test fails, stop. Fix the failure before proceeding. Do not declare done with failing tests.

### 2. Type Safety

- [ ] Run type checking: `tsc --noEmit` (TypeScript) or `cargo check` (Rust)
- [ ] Zero type errors
- [ ] No `@ts-ignore` or `@ts-expect-error` without justification
- [ ] No `any` types introduced
- [ ] Return types are explicit on public functions

**HARD GATE**: Type errors mean the code is not production-ready. Fix them.

### 3. Lint and Format

- [ ] Run linter: `eslint .` (TypeScript) or `cargo clippy` (Rust)
- [ ] Zero lint errors (warnings reviewed, not ignored)
- [ ] Code formatting applied: `prettier` (TypeScript) or `cargo fmt` (Rust)
- [ ] No new lint rules disabled without justification

### 4. Build Succeeds

- [ ] Run the build command: `npm run build`, `cargo build --release`, etc.
- [ ] Build completes without errors or warnings
- [ ] Output artifacts are correct (bundle size reasonable, no missing assets)

**HARD GATE**: If the build fails, the work is not done. Period.

### 5. No Debug Artifacts

Scan the changed files for:

- [ ] No `console.log` statements (use structured logger instead)
- [ ] No `debugger` statements
- [ ] No commented-out code blocks
- [ ] No `TODO` comments without an issue reference
- [ ] No hardcoded test values, credentials, or localhost URLs
- [ ] No temporary workarounds that bypass production logic

### 6. Regression Check

- [ ] Run the FULL test suite, not just tests for the changed code
- [ ] Compare test count before and after — no tests disappeared
- [ ] If a test was removed, confirm it was intentional and justified
- [ ] Check that unrelated features still work as expected

### 7. Visual and Behavioral Verification (if applicable)

**For UI work:**
- [ ] Verify the UI renders correctly in a browser or via Playwright
- [ ] Check responsive behavior at key breakpoints
- [ ] Test interactive elements (clicks, forms, navigation)
- [ ] Verify accessibility basics (keyboard navigation, contrast)

**For API work:**
- [ ] Test endpoints with curl, httpie, or a test client
- [ ] Verify response shapes match the expected schema
- [ ] Test error responses (400, 401, 404, 500)
- [ ] Check that auth/authz is enforced

**For CLI/bot work:**
- [ ] Run the command/bot with expected inputs
- [ ] Test with invalid inputs
- [ ] Verify output format matches expectations

### 8. Documentation Check

- [ ] If public API changed: README or API docs updated
- [ ] If configuration changed: .env.example updated
- [ ] If behavior changed: CHANGELOG entry added
- [ ] If architecture changed: relevant docs updated

## Running Verification

Execute these commands in order. Stop at the first failure.

```bash
# TypeScript project
npm test                  # or: vitest run
npx tsc --noEmit          # type check
npm run lint              # if lint script exists
npm run build             # if build script exists

# Rust project
cargo test
cargo check
cargo clippy -- -D warnings
cargo build --release
```

## After Verification Passes

Only after every applicable item in the checklist is green:

1. State explicitly: "Verification complete — all tests pass, types clean, build succeeds"
2. List what was verified (test count, build output, etc.)
3. If any item was skipped, explain why it does not apply
4. Proceed to commit or next task

## When Verification Fails

1. Identify which check failed
2. Fix the issue — do not work around it
3. Re-run verification from the beginning (not just the failed step)
4. Repeat until everything passes

**NEVER**: Declare done and mention the failure as a "known issue." Either fix it or explicitly flag it as incomplete work that needs follow-up.
