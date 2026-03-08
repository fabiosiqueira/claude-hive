---
name: systematic-debugging
description: "Find root cause before proposing fixes — reproduce, isolate, verify"
---

# Systematic Debugging

## Overview

This skill enforces a disciplined approach to debugging. The core principle: understand the problem completely before changing any code. Guessing and fixing is forbidden. Every bug gets the full investigation treatment, and every fix comes with a regression test.

Use this skill when encountering bugs, unexpected behavior, test failures, or production issues.

## The Debugging Process

### Step 1 — Reproduce

**Goal**: Create a reliable, minimal reproduction of the bug.

1. Gather information: error messages, stack traces, logs, user reports
2. Identify the exact conditions that trigger the bug
3. Create a minimal test case or script that reproduces it consistently
4. If the bug is intermittent, identify the timing or state conditions
5. Document the reproduction steps — you will need them for the regression test later

**HARD GATE**: Do not proceed to Step 2 until you can reproduce the bug on demand. If you cannot reproduce it, gather more data.

### Step 2 — Isolate

**Goal**: Narrow down the location of the bug.

1. Use binary search through the codebase:
   - Which module is responsible?
   - Which function within that module?
   - Which line within that function?
2. Techniques for isolation:
   - Comment out sections and re-test
   - Add targeted logging at suspected boundaries
   - Use `git bisect` to find the commit that introduced the bug
   - Check recent changes in the affected area with `git log --oneline -20 -- <path>`
3. Verify the isolation: can you point to a specific code region?

**HARD GATE**: Do not proceed to Step 3 until you know WHERE the bug lives. "Somewhere in this module" is not isolated enough.

### Step 3 — Hypothesize

**Goal**: Form specific, testable hypotheses about the cause.

1. Based on the isolated location, propose concrete explanations:
   - "The array is mutated in place, causing stale references"
   - "The async operation resolves after the component unmounts"
   - "The boundary check uses `<` instead of `<=`"
2. Each hypothesis must be testable — you must be able to prove or disprove it
3. Rank hypotheses by likelihood based on the evidence
4. Use STAR reasoning to structure complex bugs:
   - **Situation**: What is happening? What state is the system in?
   - **Task**: What should be happening? What constraints exist?
   - **Action**: What specific code path leads to the wrong outcome?
   - **Result**: What does the fix look like, given the constraints?

### Step 4 — Verify

**Goal**: Test each hypothesis with targeted experiments.

1. Start with the most likely hypothesis
2. Design a specific experiment that proves or disproves it:
   - Add an assertion that would fail if the hypothesis is correct
   - Temporarily modify the suspected code to see if behavior changes
   - Inspect the actual values at runtime (structured logging, not console.log)
3. If the hypothesis is wrong, move to the next one
4. If no hypothesis explains the bug, return to Step 2 — your isolation was too broad

**HARD GATE**: Do not proceed to Step 5 until you have verified the root cause. "It seems to work now" is not verification.

### Step 5 — Fix

**Goal**: Apply the minimum fix that addresses the root cause.

1. Write a test that captures the bug (this becomes the regression test)
2. The test MUST fail before the fix (RED step from TDD)
3. Apply the smallest change that fixes the root cause
4. Do NOT fix adjacent issues discovered during debugging — file them separately
5. Run the test — it MUST pass now
6. Do NOT apply workarounds or band-aids that mask the underlying issue

### Step 6 — Confirm

**Goal**: Verify the fix works AND does not introduce regressions.

1. Run the regression test — must pass
2. Run the full test suite — no new failures
3. Re-test the original reproduction steps manually
4. Check for related code paths that might have the same bug pattern
5. If the bug was in shared code, verify all callers still behave correctly

## Red Flags — Stop and Reassess

Watch for these anti-patterns during debugging:

- **Shotgun debugging**: Changing multiple things at once hoping something works
- **Symptom fixing**: The error goes away but you do not understand why
- **"It works now"**: The bug disappeared without a clear explanation of the fix
- **Scope creep**: Refactoring unrelated code while debugging
- **Assuming the test is wrong**: Modifying tests to match buggy behavior
- **Stack Overflow driven**: Applying a solution from the internet without understanding it

When you catch yourself doing any of these, stop and return to Step 1.

## Debugging Tools Checklist

- [ ] Read error messages and stack traces completely (do not skim)
- [ ] Check git history for recent changes in the affected area
- [ ] Use structured logging at system boundaries
- [ ] Inspect actual values, do not assume they are what you expect
- [ ] Check environment differences (dev vs prod, node version, OS)
- [ ] Verify dependencies are at expected versions

## Deliverables

Every debugging session produces:

1. **Root cause description**: A clear, specific explanation of what went wrong and why
2. **Regression test**: A test that would have caught the bug before it reached the user
3. **Fix**: The minimum change that addresses the root cause
4. **Verification**: Proof that all tests pass and the original reproduction no longer triggers
