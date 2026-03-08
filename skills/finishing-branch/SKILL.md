---
name: finishing-branch
description: "Complete a development branch for integration — merge, PR, or push"
---

# Finishing Branch

## Overview

This skill handles the process of completing a development branch and preparing it for integration. It covers the pre-completion checklist, the different integration options, and the cleanup steps after integration. The user always chooses the integration path — never assume.

Use this skill when a feature, fix, or refactor is implemented and verified, and it is time to integrate the work.

## Pre-Completion Checklist

Before any integration path, verify all of these are satisfied:

- [ ] All tests pass (run the full suite, not just new tests)
- [ ] Verification skill completed (types clean, lint clean, build succeeds)
- [ ] Code review completed (or explicitly skipped with user approval)
- [ ] No debug artifacts in committed code
- [ ] Documentation updated if public interface changed
- [ ] CHANGELOG entry added for user-visible changes

**HARD GATE**: Do not proceed to integration if any item above is incomplete. Go back and finish it first.

## Ask the User

Present the options clearly and wait for the user's choice:

```
Work is verified and ready for integration. Options:

1. **Merge to main** — merge this branch into main locally
2. **Create PR** — push and open a pull request for team review
3. **Commit and push** — push the branch for later integration
4. **Keep local** — keep the branch as-is, do not push yet
```

Do not assume which option the user wants. Ask explicitly.

## Option 1: Merge to Main

### Pre-Merge

1. Ensure you are on the feature branch with all changes committed
2. Fetch the latest main: `git fetch origin main`
3. Check for divergence: `git log --oneline main..HEAD` and `git log --oneline HEAD..origin/main`
4. If main has new commits, rebase or merge main into the feature branch first

### Merge

1. Switch to main: `git checkout main`
2. Pull latest: `git pull origin main`
3. Merge the feature branch: `git merge <branch-name>`
4. If conflicts arise: resolve them carefully, re-run tests after resolution
5. Run the full test suite on main after merge — do not trust the merge was clean

### Post-Merge

1. Push main: `git push origin main`
2. Delete the feature branch locally: `git branch -d <branch-name>`
3. Delete the remote branch: `git push origin --delete <branch-name>`
4. Update CHANGELOG and version if not already done

## Option 2: Create Pull Request

### Prepare the PR

1. Push the branch: `git push -u origin <branch-name>`
2. Gather PR information:
   - Review the full diff: `git diff main..HEAD`
   - Review all commits: `git log --oneline main..HEAD`
   - Identify the key changes and their motivation

### Write the PR

Use `gh pr create` with this structure:

```
Title: Short, descriptive (under 70 characters)

## Summary
- What changed and why (1-3 bullet points)

## Test plan
- How to verify the changes work
- Specific test commands or manual steps
```

### PR Quality Checks

- [ ] Title is descriptive and concise
- [ ] Description explains the WHY, not just the WHAT
- [ ] Related issues are referenced (closes #123)
- [ ] No unrelated changes included in the diff
- [ ] CI pipeline passes after push

## Option 3: Commit and Push

1. Ensure all changes are committed with clear messages
2. Push to remote: `git push -u origin <branch-name>`
3. Confirm the push succeeded
4. Inform the user the branch is available remotely for later integration

## Option 4: Keep Local

1. Ensure all changes are committed locally
2. Confirm the branch name and current state to the user
3. No remote operations — the branch stays local

## Version Management

When the integration involves a version bump:

1. Determine the version increment:
   - **patch** (0.0.x): bug fixes, minor corrections
   - **minor** (0.x.0): new features, backward-compatible changes
   - **major** (x.0.0): breaking changes
2. Update version in `package.json` or `Cargo.toml`
3. Update CHANGELOG with version, date, and summary of changes
4. Commit the version bump as a separate commit or part of the merge commit

## Post-Integration Cleanup

After successful integration (regardless of path chosen):

- [ ] Feature branch deleted (if merged)
- [ ] CHANGELOG reflects the changes
- [ ] README updated if installation or usage changed
- [ ] Version bumped if applicable
- [ ] CI/CD pipeline triggered and passing
- [ ] MEMORY.md updated if architectural decisions were made

## Handling Integration Failures

If integration fails at any point:

1. Do not force through — understand the failure
2. If merge conflicts: resolve carefully, re-run ALL tests
3. If CI fails: fix the issue on the branch, push again
4. If PR review has blocking feedback: address the feedback, re-request review
5. If build breaks on main after merge: revert immediately, fix on the branch, re-merge
