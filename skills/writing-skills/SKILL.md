---
name: writing-skills
description: "Create new Hive skills — SKILL.md files that teach Claude how to do things"
---

# Writing Skills

## Overview

This skill teaches how to create new Hive skills. A skill is a SKILL.md file inside a `skills/<name>/` directory that instructs Claude Code HOW to perform a specific task. Good skills are actionable, specific, and self-contained.

Use this skill when you need to create a new capability for the Hive system or when improving an existing skill.

## What Is a Skill

A skill is a structured instruction file that:

- Lives in `skills/<skill-name>/SKILL.md`
- Contains YAML frontmatter with metadata
- Has a markdown body with process, checklists, and rules
- Teaches Claude Code a repeatable procedure
- Can be invoked when the relevant task arises

Skills are NOT:
- Theoretical documentation or essays
- Configuration files
- Code libraries
- General knowledge articles

## The SKILL.md Format

Every skill follows this structure:

```yaml
---
name: skill-name
description: "Short description shown in skill listings"
---

# Skill Title

## Overview
What this skill does and when to invoke it.

## Process / Checklist
The step-by-step procedure to follow.

## Key Principles
Important rules and hard gates.
```

### Frontmatter Requirements

| Field | Type | Rule |
|-------|------|------|
| `name` | string | Kebab-case, must match the directory name |
| `description` | string | One sentence, under 80 characters, describes the skill's purpose |

### Body Sections

**Overview** (required)
- What the skill does in 2-3 sentences
- When to use it — specific triggers or situations
- When NOT to use it (if there are common misapplications)

**Process / Checklist** (required)
- The main procedure, broken into clear steps
- Use numbered lists for sequential steps
- Use checkbox lists `- [ ]` for verification checklists
- Include HARD GATES at critical decision points

**Key Principles** (recommended)
- Rules that apply throughout the process
- Anti-patterns to avoid
- Quality standards to meet

## Writing Good Skills

### Size It Right

- **Target**: 80-200 lines
- **Under 80 lines**: Probably too vague — add specifics, examples, or checklists
- **Over 200 lines**: Probably doing too much — split into separate skills or move detail to subsections
- **Exception**: Complex processes with many checklist items can stretch to 250 lines if every line earns its place

### Be Actionable, Not Theoretical

Every sentence should either:
1. Tell Claude what to DO
2. Tell Claude what NOT to do
3. Define a condition for when to do something

Avoid:
- "It is important to consider..." (vague)
- "Best practices suggest..." (who says?)
- "One might want to..." (passive, non-committal)

Prefer:
- "Run the test suite before proceeding" (direct action)
- "Do not merge with failing tests" (clear prohibition)
- "If the build fails, fix the error before continuing" (conditional action)

### Use Hard Gates

A HARD GATE is a checkpoint that must pass before proceeding. Format them clearly:

```markdown
**HARD GATE**: Do not proceed to Step 3 until [condition].
[What to do if the gate fails].
```

Hard gates prevent skipping critical steps. Use them for:
- Verification before integration
- Test passage before declaring done
- Reproduction before debugging
- Approval before irreversible actions

### Include Checklists

Checklists make verification concrete and exhaustive:

```markdown
- [ ] All tests pass
- [ ] No type errors
- [ ] Build succeeds
- [ ] Documentation updated
```

Each item should be independently verifiable — no compound items like "tests pass and code is clean."

### Be Self-Contained

A skill should work without loading other skills simultaneously:
- Include all necessary context within the skill
- Reference other skills by name when relevant ("see the verification skill") but do not depend on them being loaded
- Do not assume knowledge from other skill files

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Directory | kebab-case | `skills/test-driven-development/` |
| YAML name | kebab-case, matches directory | `name: test-driven-development` |
| File | Always `SKILL.md` | `skills/code-review/SKILL.md` |
| Title | Title Case | `# Code Review` |

## Skill Creation Process

### Step 1 — Define the Scope

1. What specific task does this skill cover?
2. What triggers its use? (feature implementation, bug report, deployment, etc.)
3. What is the expected outcome when the skill is applied correctly?
4. Is there an existing skill that already covers this? (do not duplicate)

### Step 2 — Draft the Process

1. Write the step-by-step procedure from start to finish
2. Identify decision points and branch paths
3. Mark critical checkpoints as HARD GATES
4. Add checklists for verification steps

### Step 3 — Add Guardrails

1. What are the common mistakes when doing this task?
2. What should Claude explicitly NOT do?
3. What are the quality standards for the output?
4. Add these as "Key Principles" or inline warnings

### Step 4 — Validate the Skill

1. Read through the skill as if you were following it for the first time
2. Check: could you complete the task using ONLY this skill's instructions?
3. Check: are there ambiguous steps that could be interpreted multiple ways?
4. Check: are the hard gates sufficient to prevent common failures?
5. Verify the line count is within the 80-200 range

### Step 5 — Create the File

1. Create the directory: `skills/<skill-name>/`
2. Write `SKILL.md` with frontmatter and body
3. Verify the `name` field matches the directory name
4. Verify the description is concise and accurate

## Anti-Patterns

- **The essay**: Pages of theory with no actionable steps — rewrite as a procedure
- **The catchall**: One skill covering multiple unrelated tasks — split it
- **The copy-paste**: Content duplicated from other sources — write original content
- **The stub**: A skeleton with TODOs and "fill in later" — finish it or do not create it
- **The novel**: 300+ lines with redundant explanations — trim to essentials
- **The dependency chain**: Skill that only works if three other skills are also loaded — make it self-contained
