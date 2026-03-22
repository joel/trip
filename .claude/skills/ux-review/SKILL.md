---
name: ux-review
description: Use this skill after runtime-test completes to review the user experience, flow coherence, and accessibility of new or changed UI. Trigger when the user says "ux review", "check the flow", "accessibility check", or after any phase that introduces new pages, forms, or navigation changes. Also trigger automatically after runtime-test passes, before a PR is opened. This skill reviews what the browser sees, not just what the code says — always use agent-browser screenshots as the primary source of truth.
---

# UX Review

Review the user-facing experience of changes introduced in the current branch. This skill focuses on flow, clarity, and accessibility — not aesthetics. The primary source of truth is live screenshots from `agent-browser`, not code inspection.

## Project Context

- **App URL:** `https://catalyst.workeverywhere.docker/`
- **Views:** Phlex components (not ERB) — views in `app/views/`, components in `app/components/`
- **Design system:** Tailwind CSS with custom design tokens (`ha-button`, `ha-button-primary`, `ha-button-secondary`, `ha-button-danger`, `ha-card`, `ha-text`, `ha-muted`)
- **Dark mode:** Class-based toggle via Stimulus `theme_controller.js`. Toggle button in sidebar.
- **Navigation:** Sidebar layout with section links, auth nav (Sign in / My account / Sign out)
- **Feedback:** Flash messages rendered as toast notifications via Stimulus `toast_controller.js`
- **Authorization-aware UI:** Buttons/links are conditionally rendered via `allowed_to?` — verify that hidden actions actually stay hidden (no phantom buttons)

## Prerequisites

- App must be running (`bin/cli app restart`)
- `agent-browser` available

## Step 1: Identify Changed Surfaces

From the diff, list every page, form, modal, or flow that was added or modified:

```bash
git diff main...HEAD --name-only | grep -E "(views|components)"
```

## Step 2: Screenshot Each Changed Surface

For each identified surface, take a screenshot in both light and dark mode using `agent-browser`.

Also test at a narrow viewport (375px) to catch mobile/responsive issues.

## Checklist

### Flow & Clarity
- [ ] Is the primary action on each page obvious without reading everything?
- [ ] Are error states visible and actionable (not just "something went wrong")?
- [ ] Are success states confirmed with feedback (flash toast, redirect, or visual change)?
- [ ] Do multi-step flows (e.g. signup -> verify -> login) feel connected, not jarring?
- [ ] Are empty states handled (e.g. "No trips yet" rather than a blank page)?

### Forms
- [ ] Are labels present on all inputs (not just placeholder text)?
- [ ] Is the submit button clearly distinguishable from secondary actions? (`ha-button-primary` vs `ha-button-secondary`)
- [ ] Are validation errors shown inline, near the field that caused them?
- [ ] Can the form be submitted with the keyboard alone (Tab + Enter)?

### Navigation
- [ ] Does the active page/section appear selected in the sidebar?
- [ ] Are "Back to ..." links present where the user might feel lost?
- [ ] Does the page title reflect what's on screen?
- [ ] Do breadcrumb-style section labels in `PageHeader` make sense? (e.g. section: "Trips", title: trip name)

### Authorization-Aware UI
- [ ] Are action buttons (Edit, Delete, New, Add member, Remove) hidden for users without permission?
- [ ] Are there no "phantom" buttons visible that lead to 403 errors?
- [ ] Does the "Members" link remain visible to viewers (intentional — they can see who's on the trip)?
- [ ] Is the "New entry" button hidden on non-writable trips?

### Accessibility (basic)
- [ ] Are interactive elements reachable by keyboard?
- [ ] Are buttons and links distinguishable by more than just color?
- [ ] Is text contrast sufficient in both light and dark mode?
- [ ] Are images or icons meaningful to screen readers (alt text or aria-label)?

### Responsive
- [ ] Does the layout hold at 375px width without horizontal scrolling?
- [ ] Are touch targets large enough on mobile (44x44px minimum)?

## Output Format

```
## UX Review — <branch name>

### Broken (blocks usability)
- <issue>: <page/component> — <what's wrong and recommended fix>

### Friction (degrades experience)
- <issue>: <page/component> — <what's wrong and recommended fix>

### Suggestions (nice to have)
- <observation>

### Screenshots reviewed
- <list of pages/viewports tested>
```

## Fixing Issues

For each Broken issue, fix before the PR. Follow github-workflow commit conventions.

For Friction issues, ask the user: fix now or create a follow-up issue?

Use the `/github-workflow` skill to create follow-up issues for deferred items, labelled `enhancement`.
