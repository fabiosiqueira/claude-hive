---
name: brainstorming
description: "Refine requirements through collaborative dialogue before any implementation"
---

# Brainstorming

## Overview

Brainstorming is the first phase of the Hive pipeline. Its purpose is to transform a vague idea or request into a precise, approved design document. No code is written during this phase. The output is a design document saved to `docs/plans/` that becomes the input for the planning phase.

Use this skill when starting a new feature, project, or significant change. Skip it only for trivial, unambiguous tasks (single-file fix with obvious solution).

## Process

### Step 1: Understand Context

Before asking the user anything, gather project context silently:

- Read `CLAUDE.md` at the project root for architecture, conventions, and constraints
- Scan existing code structure (directories, key files, package.json/Cargo.toml)
- Check `docs/` for existing design specs, plans, or ADRs
- Check `MEMORY.md` for prior decisions relevant to the request
- Identify what already exists that relates to the user's request

Do NOT ask the user questions you can answer by reading the codebase.

### Step 2: Ask Clarifying Questions

Ask questions **one at a time**. Wait for the answer before asking the next.

Guidelines for good questions:

- Prefer multiple choice over open-ended: "Should we use (A) REST API, (B) GraphQL, or (C) tRPC?"
- Each question should resolve a genuine ambiguity — never ask for information already in the codebase
- Group related concerns into a single question when natural
- Stop asking when you have enough clarity to propose approaches (typically 3-6 questions)
- If the user says "you decide", make the decision, state your reasoning, and move on

### Step 3: Propose Approaches

Present 2-3 distinct approaches with explicit trade-offs:

```markdown
## Approach A: <Name>
- **How**: Brief description of the technical approach
- **Pros**: What it does well
- **Cons**: What it sacrifices
- **Fits when**: Under what circumstances this is the best choice

## Approach B: <Name>
...

## Recommendation
Approach X because <concrete reasoning tied to project constraints>.
```

Rules:
- Each approach must be genuinely different (not minor variations)
- Trade-offs must reference the specific project, not generic pros/cons
- Include a clear recommendation with reasoning
- If one approach is obviously superior, say so — don't artificially balance

### Step 4: Present Design

After the user selects or modifies an approach, present the full design in sections:

1. **Goal** — One paragraph: what we are building and why
2. **Scope** — What is included and what is explicitly excluded
3. **Technical Design** — Architecture, data model, key interfaces, integration points
4. **File Structure** — Exact paths for new/modified files
5. **Edge Cases** — Known boundary conditions and how they are handled
6. **Out of Scope** — Things deliberately deferred

Present each section and get approval before moving to the next. If the user pushes back on a section, revise it before continuing.

### Step 5: Save Design Document

Once all sections are approved, save the complete design to:

```
docs/plans/YYYY-MM-DD-<topic>-design.md
```

The document must be self-contained — a reader with no context should understand what is being built, why, and how.

### Step 6: Transition

After saving, inform the user:

> "Design approved and saved to `docs/plans/<filename>`. Ready to generate the implementation plan. Proceed with `/hive-plan`?"

## Hard Gates

- **No implementation before design approval.** Not a single line of code, not a test, not a schema change.
- **No skipping clarifying questions.** If assumptions are wrong, the entire plan is wrong.
- **No vague designs.** Every section must have concrete details — file paths, data structures, interface signatures.

## Key Principles

- **Listen more than talk.** The user knows their domain; you know the technical constraints.
- **Questions reduce waste.** Five minutes of questions saves hours of rework.
- **Trade-offs are decisions, not lists.** Every approach must lead to a clear recommendation.
- **Designs are contracts.** Once approved, the design is the source of truth for planning and implementation.
- **Scope boundaries prevent creep.** Explicitly state what is NOT being built.
- **Context first, questions second.** Read the codebase before asking the user what is already documented.
