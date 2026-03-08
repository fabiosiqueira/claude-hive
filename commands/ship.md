---
description: "Final deploy -- version bump, changelog, commit, push, PR, and Hive run cleanup."
disable-model-invocation: true
---

# /ship -- Final Deploy (Phase 7)

You are preparing the project for deploy. This is the final phase of the Hive pipeline, executed after the security review passes.

## Process

### 1. Pre-Deploy Verification

Confirm all checks pass before proceeding:
- [ ] All tests pass (`npm test` or equivalent)
- [ ] Build completes without errors (`npm run build` or equivalent)
- [ ] TypeScript has no errors (`npx tsc --noEmit`)
- [ ] No sensitive files staged (`.env`, credentials, keys)

If any check fails, stop and fix before continuing.

### 2. Version Bump (Semver)

Determine the version based on the nature of changes:
- **patch** (0.0.X): bug fixes, minor corrections
- **minor** (0.X.0): new features, enhancements
- **major** (X.0.0): breaking changes

Update the version in `package.json` (if present).

### 3. CHANGELOG

Add an entry to `CHANGELOG.md` following Keep a Changelog format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- [new features]

### Changed
- [changes to existing features]

### Fixed
- [bug fixes]

### Security
- [security fixes]
```

Create `CHANGELOG.md` if it does not exist.

### 4. README

Check whether `README.md` needs updates:
- Did installation instructions change?
- Did the public interface change?
- Are there new commands or configuration options?

Update if necessary.

### 5. CLAUDE.md / MEMORY.md

Check for new decisions or patterns that should be persisted:
- Architectural decisions
- New established patterns
- Important configuration changes

Update the relevant files if necessary.

### 6. Hive Run Cleanup

If `.hive/runs/` contains state from the current pipeline run:
- Verify all tasks in the run are marked complete
- Clean up temporary run state that is no longer needed
- Preserve run logs that may be useful for future reference

### 7. Commit + Push

Execute the commit following the project conventions:
1. Stage specific files (never `git add .`)
2. Commit with a Conventional Commits message
3. Push to remote

### 8. Pull Request (if on a branch)

If working on a branch other than main:
- Create a PR via `gh pr create`
- Short, descriptive title
- Body with summary and test plan

### 9. Docker (if applicable)

If the project uses Docker:
```bash
docker compose build
docker compose up -d
```

Confirm containers are running.

## Gate

The deploy is complete when:
- [ ] Version bumped in `package.json`
- [ ] `CHANGELOG.md` updated
- [ ] `README.md` updated (if needed)
- [ ] Code committed and pushed
- [ ] PR created (if on a branch)
- [ ] Hive run state cleaned up
- [ ] Containers running (if Docker)

Present the summary to the user:
```
Ship complete:
- Version: X.Y.Z
- Commits: N
- PR: [URL] (if applicable)
- Hive run: cleaned
- Status: deployed / pushed
```
