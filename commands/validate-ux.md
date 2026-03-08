---
description: "Validate UX with real interaction tests -- navigation, forms, responsiveness, accessibility."
disable-model-invocation: true
---

# /validate-ux -- UX Validation with Playwright (Phase 5)

You are validating the user experience of the project with real browser interactions. This is Phase 5 of the Hive pipeline, executed after implementation (`/hive-dispatch`) and before the security review.

## Prerequisites

1. The project must be running locally (dev server active)
2. Playwright MCP or browser automation must be available
3. Design spec in `docs/design-spec.md` serves as the visual reference
4. Implementation from `/hive-dispatch` must be complete with all tests passing

If the dev server is not running, start it before proceeding.

## Validation Process

### 1. Interaction Inventory

Read the plan in `docs/plans/` and the design spec in `docs/design-spec.md`.
Build a checklist of every interaction to test:

```
For each page:
- [ ] Navigation: page loads without errors
- [ ] Links: all internal links resolve correctly
- [ ] Buttons: all buttons respond to click
- [ ] Forms: fields accept input, validation fires, submit works
- [ ] Responsiveness: layout intact at mobile (375px) and desktop (1280px)
- [ ] Accessibility: tab navigation, labels present, sufficient contrast
```

### 2. Execute Tests via Browser Automation

For each interaction in the inventory:

**Navigation:**
- Navigate to the URL
- Take a screenshot
- Confirm expected elements are visible

**Forms:**
- Click into fields
- Fill with valid data and submit -- verify success response
- Fill with invalid data and submit -- verify error messages appear

**Responsiveness:**
- Set viewport to mobile (375x812), take screenshot, verify layout holds
- Set viewport to desktop (1280x800), take screenshot, verify layout holds

**Basic Accessibility:**
- Verify all inputs have associated labels
- Verify all buttons have accessible text
- Check contrast ratios where tooling allows

### 3. Document Results

For each test:
- Record PASS or FAIL
- For FAIL: capture a screenshot and describe the issue

### 4. Fix or Defer

If failures are found, ask the user:
"Found N UX issues. Should I fix them now or document them for a later fix?"

If fixing: apply corrections, then re-run the failing tests from Step 2 to confirm resolution.

## Gate

UX validation passes when:
- [ ] Every page loads without console errors
- [ ] All forms work end-to-end (valid + invalid input)
- [ ] All buttons and links respond correctly
- [ ] Layout does not break at mobile and desktop viewports
- [ ] No critical accessibility issues

Once the gate passes, the pipeline advances to Phase 6 (`/security-review`).
