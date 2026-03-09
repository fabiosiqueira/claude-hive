---
description: "Diagnose a bug, plan the fix, get approval, and execute — with direct fix or parallel workers."
disable-model-invocation: true
---

# /hive-debug -- Debug and Fix

You are running the Hive debug pipeline. Invoke the `hive:debug` skill to begin.

The skill will:
1. Collect the error input (text, stack trace, optional image path)
2. Diagnose the root cause using STAR reasoning
3. Evaluate fix complexity (direct vs workers)
4. Present a fix plan and wait for user approval
5. Execute the fix (TDD for direct; `/hive-dispatch` for complex)
6. Verify all tests pass

Provide your error description, stack trace, or image path to start.
