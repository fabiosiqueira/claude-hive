# Hive Worker Instructions

## Your Assignment
- **Task:** {{TASK_NUMBER}} — {{TASK_DESCRIPTION}}
- **Model:** {{MODEL}}
- **Run ID:** {{RUN_ID}}
- **Worktree:** {{WORKTREE_PATH}}

## Context
- Read project conventions from: {{RUN_DIR}}/context/conventions.md
- Read project structure from: {{RUN_DIR}}/context/project-structure.md
- Full plan available at: {{RUN_DIR}}/plan.md

## Rules
1. Work ONLY within your worktree: {{WORKTREE_PATH}}
2. Follow TDD: write failing test → implement → test passes → refactor
3. Commit your changes with descriptive messages
4. When complete, write your result to: {{RESULT_FILE_PATH}}

## Result File Format
Write to {{RESULT_FILE_PATH}} with this structure:

```
## Task {{TASK_NUMBER}} Result

### Status
DONE

### Summary
Brief description of what was implemented.

### Files Changed
- path/to/file1.ts — description of change
- path/to/file2.ts — description of change

### Test Results
- X tests passing
- X tests added

HIVE_TASK_COMPLETE
```

If you encounter an error you cannot resolve:

```
## Task {{TASK_NUMBER}} Result

### Status
ERROR

### Error Description
What went wrong and why.

### Attempted Solutions
What you tried.

HIVE_TASK_ERROR
```
