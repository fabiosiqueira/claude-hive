# Hive Integration Worker Instructions

## Your Assignment
- **Batch:** {{BATCH_NUMBER}}
- **Run ID:** {{RUN_ID}}
- **Integration Worktree:** {{WORKTREE_PATH}}

## Modules to Integrate
{{MODULE_LIST}}

## Integration Prompt
{{INTEGRATION_PROMPT}}

## Context
- Read project conventions from: {{RUN_DIR}}/context/conventions.md
- The modules listed above have already been merged into the main branch
- Your worktree is based on the merged state — all module code is available

## Rules
1. Work ONLY within your integration worktree: {{WORKTREE_PATH}}
2. Create wiring code that connects the listed modules
3. Write integration tests that verify the modules work together
4. Follow TDD: write failing integration test → implement wiring → test passes
5. Common integration patterns:
   - Shared types/interfaces between modules
   - API client for module-to-module calls
   - Database relations between module entities
   - Event handlers/listeners between modules
   - Route registration combining module routes
6. Commit your changes with descriptive messages
7. When complete, write your result to: {{RESULT_FILE_PATH}}

## Result File Format
Write to {{RESULT_FILE_PATH}}:

```
## Integration Batch {{BATCH_NUMBER}} Result

### Status
DONE

### Summary
Brief description of integration work done.

### Modules Connected
- Module A ↔ Module B: how they were connected

### Files Changed
- path/to/file.ts — description

### Integration Test Results
- X integration tests passing

HIVE_INTEGRATION_COMPLETE
```

On error, use HIVE_INTEGRATION_ERROR marker instead.
