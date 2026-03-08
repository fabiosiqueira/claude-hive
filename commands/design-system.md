---
description: "Generate a complete design system -- palette, typography, components, and layouts."
disable-model-invocation: true
---

# /design-system -- Design System Generator (Phase 3)

You are generating the design system for the current project. This is Phase 3 of the Hive pipeline, executed after planning (`/hive-plan`) and before implementation (`/hive-dispatch`).

## Context Gathering

Before starting, read silently:
1. The plan or PRD in `docs/plans/` (use the most recent one)
2. The project `CLAUDE.md` for stack and constraints
3. Any existing design spec in `docs/design-spec.md`

## Process

### 1. Define Foundations

If the plan does not already specify these, ask the user:
- **Mood/style**: modern, minimalist, bold, corporate, playful?
- **Primary colors**: any brand or preference?
- **Target audience**: who will use this?

Keep the questions focused -- 2-3 max. Use multiple-choice when possible.

### 2. Generate Design Tokens

Produce a complete token set:

```
Palette:
- Primary (shades 50-950)
- Secondary
- Accent
- Neutral (grays)
- Semantic: success, warning, error, info

Typography:
- Font families (heading + body)
- Type scale (xs, sm, base, lg, xl, 2xl, 3xl)
- Line heights and letter spacing

Spacing:
- 4px base scale (1=4px, 2=8px, 3=12px, 4=16px...)

Borders:
- Border radius scale
- Border widths

Shadows:
- sm, md, lg, xl
```

### 3. Map Components

Using the plan from `docs/plans/` as reference, enumerate every UI component needed:

```
For each component:
- Name
- Corresponding shadcn/ui component (or custom)
- Required variants
- States (default, hover, active, disabled, error)
```

### 4. Define Layouts

For each page or screen in the plan:
- Grid layout (columns, breakpoints)
- Component hierarchy
- Responsive behavior (mobile-first)

### 5. Save Spec

Write the complete design system to `docs/design-spec.md`:

```markdown
# Design System -- [Project Name]

## Tokens
[palette, typography, spacing, borders, shadows]

## Components
[list with variants and states]

## Layouts
[per-page layouts]

## Tailwind Config
[required extensions for tailwind.config.ts]
```

### 6. Generate Tailwind Config

Create or update `tailwind.config.ts` with the custom tokens from the spec.

## Gate

The design system is complete when:
- [ ] `docs/design-spec.md` exists with all token categories
- [ ] Every component from the plan is mapped (shadcn/ui or custom)
- [ ] Layouts defined for all pages in the plan
- [ ] `tailwind.config.ts` updated with custom tokens

Present the result to the user and get explicit approval before the pipeline advances to Phase 4 (`/hive-dispatch`).
