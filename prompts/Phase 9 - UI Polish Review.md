# UI Polish Review -- Phase 9 (Hardening & API Polish)

**Branch:** `feature/phase-9-hardening-api-polish`
**Reviewed against:** `main`
**Date:** 2026-03-24

## Scope

Phase 9 changed only one UI component: `app/components/comment_card.rb`. The changes added:

1. An inline edit toggle using a `<details>/<summary>` element with an "Edit" link.
2. An inline edit form (textarea + Save button) revealed when the `<details>` is opened.
3. A `can_edit?` authorization method (using `allowed_to?(:update?, @comment)`) to conditionally render the edit toggle.
4. Renamed `can_modify?` to `can_destroy?` for clarity.

The rest of Phase 9 was backend work (MCP tools, policies, specs) with no visual impact.

---

## Changed Surfaces

| File | Change |
|---|---|
| `app/components/comment_card.rb` | Added `render_edit_toggle`, `render_edit_form`, `can_edit?`, renamed `can_modify?` to `can_destroy?` |

No changes to `application.css`, layouts, or other components.

---

### Spatial Composition: Adequate

- The edit toggle ("Edit" link) is placed at `mt-3` below the comment body, which provides adequate vertical separation from the text above. This spacing mirrors the body paragraph's own `mt-3` from the header, creating a consistent internal rhythm within the card.
- The edit form appears at `mt-2` inside the `<details>`, with `space-y-3` between the textarea and the Save button. This is tight but appropriate for an inline editing context -- the form should feel like a natural extension of the card, not a separate section.
- The Save button sits alone in a `flex items-center gap-2` container, but there is no Cancel button or closing mechanism other than re-clicking the `<summary>`. This is functionally acceptable (clicking "Edit" again collapses the form) but spatially, a Cancel action would balance the button row.
- When the edit form is expanded, the card grows vertically. The `space-y-4` on the comments container provides enough gap between cards to prevent the expanded form from visually colliding with the next comment card.

**Observations from screenshots:**
- In the desktop view, the expanded edit form (textarea + Save) occupies roughly 50% of the card height, which is proportional.
- The textarea has 3 rows, providing adequate height for short comment edits.
- The Save button is left-aligned, which is consistent with the header's left-aligned author name and body text. This creates a clean left edge throughout the card.

**Recommendation:** Consider adding a Cancel button next to Save for explicit dismissal. This would be a `ha-button ha-button-secondary text-sm` to match the design system. Effort: one-liner.

---

### Typography: Strong

- The "Edit" link uses `text-xs text-[var(--ha-accent)]`, which correctly positions it as a tertiary action -- smaller than the comment body (`text-sm`) and the author name (`text-sm font-semibold`). The type hierarchy within the card is: author name (sm/semibold) > body (sm/regular) > timestamp and actions (xs).
- The Save button inherits `ha-button ha-button-primary text-sm`, which gives it appropriate visual weight for a form submission action within the card context.
- The textarea uses `ha-input text-sm`, matching the comment body text size. When editing, the text in the textarea reads at the same size as the displayed comment, which is the correct choice -- the user sees exactly what they typed at the size it will render.

No issues found.

---

### Color & Contrast: Strong

- The "Edit" link uses `text-[var(--ha-accent)]` (sky blue) with `hover:text-[var(--ha-accent-strong)]` (deeper sky blue). This is the correct token for a non-destructive action link, distinguishing it from the "Delete" button which uses `text-[var(--ha-danger)]` (red).
- In dark mode, the accent color (`#38bdf8`) has strong contrast against the surface background (`#0f172a`), verified in the dark mode screenshot. The "Edit" text is clearly readable.
- The Save button uses `ha-button-primary` (sky blue background, dark text), which is the correct primary action style and stands out appropriately within the card.
- The token system is used consistently -- no hardcoded color values in the new code.

No issues found.

---

### Shadows & Depth: Adequate

- Comment cards intentionally omit the `ha-card` class and its associated drop shadow. They use `bg-[var(--ha-surface)]` with a `border` instead, which positions comments as subordinate content within the journal entry page. This is the correct visual hierarchy: the journal entry details card uses `ha-card p-6` with shadow, while comment cards are lighter-weight surface elements.
- The edit form textarea uses `ha-input`, which gets a `box-shadow: 0 0 0 3px var(--ha-ring-shadow)` on focus. This provides adequate visual feedback when the user clicks into the textarea.
- The Save button gets the `ha-button-primary` shadow (`0 14px 30px -24px rgba(14, 165, 233, 0.7)`), which adds subtle depth to the action button.

No issues found with the new additions.

---

### Borders & Dividers: Adequate

- The comment card uses `border border-[var(--ha-border)]`, which provides clear card delineation in both light and dark mode. In light mode, the `#e2e8f0` border is visible against the `#ffffff` surface. In dark mode, the `#1f2937` border is visible against the `#0f172a` surface.
- The edit form textarea uses `ha-input`, which inherits `border: 1px solid var(--ha-border)`. This creates a nested border (textarea inside card), but the two borders use the same color token, which feels cohesive.
- There is no visual separator between the comment body and the edit toggle. The `mt-3` margin provides spacing but no border or divider. This is appropriate -- a border would add too much visual weight to a tertiary action link.

**Minor observation:** The edit form sits inside the comment card without any visual boundary separating it from the comment body above. In the expanded state, the card contains: header, body, "Edit" link, then immediately the textarea. The `mt-2` gap between the "Edit" summary and the form container is the only separation. A very subtle `border-t border-[var(--ha-border)]` with `pt-3` on the edit form container could create a clearer zone boundary. Effort: one-liner. This is optional and a matter of taste.

---

### Transitions & Motion: Weak

- The `<details>/<summary>` element toggles the edit form with no transition. When clicked, the form appears/disappears instantly -- a hard cut rather than a smooth reveal. This is the native browser behavior for `<details>`, and Tailwind/CSS does not easily animate `<details>` content height changes.
- The comment card itself has `transition-colors duration-150` for hover state, which works correctly. Hovering over a comment card produces a smooth background color shift.
- The "Edit" link has `hover:text-[var(--ha-accent-strong)]` but no `transition` class, so the color change on hover is instant (a hard snap). This is inconsistent with other interactive elements in the design system that use `transition-all duration-150` or `transition-colors duration-150`.

**Recommendations:**
1. Add `transition-colors duration-150` to the "Edit" summary element's class string. Currently: `"text-xs text-[var(--ha-accent)] hover:text-[var(--ha-accent-strong)] cursor-pointer list-none"`. Add: `transition-colors duration-150`. Effort: one-liner.
2. The instant reveal of the edit form is acceptable for now. A smooth height animation would require either JavaScript (Stimulus controller) or a CSS-only approach using `grid-template-rows` transition on a wrapper div instead of `<details>`. Effort: moderate to significant.

---

### Micro-Details: Adequate

- **Cursor state:** The "Edit" summary has `cursor-pointer`, which is correct for a clickable element. The Save button inherits `cursor: pointer` from the `ha-button` class. The Delete button uses a form `button_to`, which also gets pointer cursor by default.
- **Border radius consistency:** The textarea uses `ha-input` with `border-radius: 16px`. This sits inside a card with `rounded-xl` (12px). A 16px-radius element inside a 12px-radius container is an intentional design choice in this system (inputs are slightly rounder than their containers), matching the existing `ha-input` / `ha-card` relationship elsewhere.
- **`list-none` on summary:** The `list-none` class in the summary removes the default disclosure triangle. The CSS layer also includes global `summary { list-style: none; }` and `summary::-webkit-details-marker { display: none; }`, so the `list-none` class is redundant but harmless -- it acts as defensive CSS.
- **Form CSRF:** The `form_with` helper automatically includes the CSRF token, so the edit form is secure.
- **No loading state:** The Save button has no loading/disabled state during form submission. If the user clicks Save and the request takes time, there's no visual feedback. This is a general pattern in the app (the comment create form also lacks this), not specific to Phase 9.

**Recommendation:** The "Edit" text could benefit from an icon or a subtle visual indicator that it toggles something (e.g., a pencil icon or a chevron). Currently, the word "Edit" alone serves as the toggle affordance, which is clear but minimal. Effort: moderate (requires adding an SVG icon component).

---

### CSS Architecture

- **No new CSS classes needed.** The Phase 9 changes use existing `ha-input`, `ha-button`, and `ha-button-primary` classes correctly. The inline Tailwind is minimal and contextual (`mt-3`, `mt-2`, `space-y-3`, `text-xs`), which is appropriate per the project's hybrid approach.
- **No patterns approaching extraction threshold.** The edit form is a one-off pattern within the comment card. If edit-in-place were added to other components (journal entry body, checklist item content), a shared `ha-inline-edit` component class might be warranted, but currently there is only one instance.
- **Token usage is correct.** All colors reference CSS custom properties (`--ha-accent`, `--ha-accent-strong`). No hardcoded Tailwind color classes in the new code.

---

### Screenshots Reviewed

| Page | Viewport | Theme | Screenshot |
|---|---|---|---|
| Journal Entry Show (Glacier Lagoon) - header | 1280x720 | Light | `/tmp/ui-polish-desktop-je-top.png` |
| Journal Entry Show (Glacier Lagoon) - comments, edit form collapsed | 1280x720 | Light | `/tmp/ui-polish-desktop-comments.png` |
| Journal Entry Show (Glacier Lagoon) - comments, edit form expanded | 1280x720 | Light | `/tmp/ui-polish-desktop-comments-light-final.png` |
| Journal Entry Show (Glacier Lagoon) - comments, edit form expanded | 1280x720 | Dark | `/tmp/ui-polish-desktop-comments-dark.png` |
| Journal Entry Show (Glacier Lagoon) - comments, full resolution | 1280x720 | Light | `/tmp/ui-polish-tokyo-comments2.png` |
| Journal Entry Show (Arrival in Tokyo) - comments by other users | 1280x720 | Light | `/tmp/ui-polish-tokyo-comments-large.png` |
| Journal Entry Show (Glacier Lagoon) - mobile comments | 375x812 | Light | `/tmp/ui-polish-comment-edit-visible.png` |

---

## Summary of Recommendations

| # | Recommendation | Effort | Dimension | Priority |
|---|---|---|---|---|
| 1 | Add `transition-colors duration-150` to the "Edit" summary class string for smooth hover color change | One-liner | Transitions | High |
| 2 | Add a Cancel button (`ha-button ha-button-secondary text-sm`) next to Save in the edit form for explicit dismissal | One-liner | Spatial | Medium |
| 3 | Optionally add a subtle `border-t border-[var(--ha-border)] pt-3` to the edit form container to visually separate it from the comment body | One-liner | Borders | Low |
| 4 | Consider a smooth reveal animation for the edit form (replacing `<details>` with a Stimulus toggle or CSS `grid-template-rows` transition) | Significant | Transitions | Low |
| 5 | Add a pencil icon or chevron to the "Edit" toggle for stronger affordance | Moderate | Micro-Details | Low |

---

## Overall Assessment

The Phase 9 UI change is small and well-executed. The inline edit form follows the design system correctly -- using `ha-input`, `ha-button`, and `ha-button-primary` classes, with proper CSS custom property tokens for colors. The authorization guard (`can_edit?`) correctly gates the edit UI, and the `<details>/<summary>` pattern provides a no-JS toggle mechanism that is functional and accessible.

The main area for improvement is the transition behavior: the "Edit" link lacks a smooth hover color transition (one-liner fix), and the form reveal is an instant cut rather than a smooth animation (more involved fix). These are polish items, not functional issues.

The previous UI Polish review recommendations (from Phase 5/6) have been fully incorporated -- the comment card now has `rounded-xl`, `border border-[var(--ha-border)]`, `transition-colors duration-150`, and `hover:bg-[var(--ha-surface-hover)]`, all of which were missing in earlier iterations.

Want me to apply these fixes?
