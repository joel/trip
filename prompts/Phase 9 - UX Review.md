# UX Review -- feature/phase-9-hardening-api-polish

**Date:** 2026-03-24
**Reviewer:** Claude (automated UX review)
**Branch:** `feature/phase-9-hardening-api-polish`
**Compared against:** `main`

---

## Scope of Changes

### UI Changes
- **CommentCard component** (`app/components/comment_card.rb`): Added inline comment editing via `<details>/<summary>` toggle with a `form_with` textarea and Save button. Separated `can_edit?` and `can_destroy?` permission checks (previously a single `can_modify?`).

### Non-UI Changes (not reviewed for UX, noted for context)
- **Policy fixes:** Corrected operator precedence in `CommentPolicy`, `ReactionPolicy`, `ChecklistPolicy`, `ChecklistItemPolicy` so that superadmins are also subject to trip state guards (e.g., cannot comment on non-commentable trips).
- **MCP tools:** Extracted shared `success_response`/`error_response` helpers into `BaseTool`. Added `validate_actor_type!` guard, `RecordNotFound` rescue in `resolve_trip`, input schema `enum` constraints, and limit clamping. Improved code formatting for line-length compliance.
- **Seeds:** Added `jack@system.local` system actor user.
- **System spec:** Added `spec/system/comments_spec.rb` for inline comment editing.

---

## Broken (blocks usability)

None found. The core comment editing flow works correctly: the `<details>` toggle opens, the textarea is pre-filled with the current comment body, saving via Turbo Stream replaces the card in-place without a full page reload, and the form collapses after save.

---

## Friction (degrades experience)

### F1: No Cancel button on inline edit form
**Component:** `CommentCard#render_edit_form`
**What's wrong:** The edit form only has a "Save" button. There is no explicit "Cancel" button or link. The user must discover that clicking "Edit" again (the `<summary>` toggle) collapses the form. This is not obvious.
**Recommended fix:** Add a secondary-styled "Cancel" button next to "Save" that closes the `<details>` element, either via a Stimulus action (`details.open = false`) or by wrapping the toggle in a small controller. Example:
```ruby
div(class: "flex items-center gap-2") do
  form.submit "Save", class: "ha-button ha-button-primary text-sm"
  button(
    type: "button",
    class: "ha-button ha-button-secondary text-sm",
    onclick: "this.closest('details').open = false"
  ) { "Cancel" }
end
```

### F2: Validation errors on comment edit cause a full-page redirect
**Component:** `CommentsController#update` failure path
**What's wrong:** When the update fails (e.g., empty body), the `Dry::Monads::Failure` branch only handles `format.html` with `redirect_to [@trip, @journal_entry], alert: ...`. Since Turbo submits the form as a Turbo Stream request and there is no `format.turbo_stream` handler for failures, Turbo falls back to following the HTML redirect. This causes a full-page navigation, losing scroll position and the edit form state. The flash alert may appear at the top of the page, far from the edit form.
**Recommended fix:** Add a `format.turbo_stream` branch in the `Failure` case that re-renders the comment card with errors, or use `turbo_stream: stream_replace(...)` to replace the card with a version showing inline validation errors. Alternatively, render the form with `status: :unprocessable_content` so Turbo keeps the user on the same page.

### F3: Edit textarea has no accessible label
**Component:** `CommentCard#render_edit_form`
**What's wrong:** The `form.text_area(:body)` generates a `<textarea>` with no associated `<label>`, no `aria-label`, and a generic `id="comment_body"`. Screen readers cannot identify the purpose of this field. Additionally, when multiple comment cards are on the page, all edit textareas share the same `id="comment_body"`, which is invalid HTML (duplicate IDs).
**Recommended fix:** Either add a visually hidden label or use `aria-label`:
```ruby
form.text_area(
  :body,
  rows: 3,
  class: "ha-input w-full text-sm",
  aria: { label: "Edit comment" }
)
```
For the duplicate ID issue, consider passing a unique ID based on the comment:
```ruby
form.text_area(
  :body,
  id: "comment_body_#{@comment.id}",
  rows: 3,
  class: "ha-input w-full text-sm",
  aria: { label: "Edit comment" }
)
```

### F4: "Add a comment" textarea also lacks a label
**Component:** `CommentForm`
**What's wrong:** The comment creation form's textarea has `placeholder: "Add a comment..."` but no `<label>` or `aria-label`. Placeholder text alone is not an accessible label -- it disappears when the user starts typing, and some screen readers do not announce placeholders.
**Note:** This is a pre-existing issue, not introduced in Phase 9, but noted here since the comment area was modified.

---

## Suggestions (nice to have)

### S1: Show "edited" indicator on updated comments
After a comment is edited, there is no visual indicator that it was modified. Consider showing "(edited)" or a last-updated timestamp next to the creation time, similar to how Slack or GitHub display edited comments.

### S2: Consider using a Turbo Frame for the edit form instead of `<details>`
The `<details>/<summary>` pattern works but has limitations:
- The triangle disclosure marker must be hidden via CSS (`list-none`), adding visual complexity.
- The open/close state is not managed by Turbo, so after a Turbo Stream replace the form always renders closed (which is actually the desired behavior here, but could cause issues if the pattern is extended).
- A Turbo Frame approach would allow the server to control the rendered state (show form vs. show text) and handle errors more gracefully.

### S3: Reaction emoji buttons lack `aria-label`
The reaction buttons in the reactions summary (thumbs up, heart, etc.) are emoji-only with no text label or `aria-label`. Screen readers would announce them as empty buttons or raw Unicode characters. This is pre-existing but worth noting.

### S4: Mobile sidebar layout pushes content off-screen
At 375px viewport width, the sidebar takes significant space and pushes the main content area to the right, causing comment cards and form fields to be very narrow (characters stack vertically in textareas). This is a pre-existing responsive layout issue, not introduced in Phase 9.

---

## Screenshots Reviewed

| Page / State | Viewport | Mode | Observation |
|---|---|---|---|
| Home (logged out) | 1280x720 | Light | Renders correctly |
| Sign in page | 1280x720 | Light | Renders correctly |
| Trips list | 1280x720 | Light | Renders correctly |
| Trip detail (Iceland Road Trip) | 1280x720 | Light | Journal entries visible with comment counts |
| Journal entry (Glacier Lagoon) - comments section | 1280x720 | Light | Comments render with Edit/Delete actions visible |
| Comment edit form expanded | 1280x720 | Light | Textarea pre-filled, Save button visible, no Cancel button |
| Comment edit form expanded | 1280x720 | Dark | Good contrast, all elements readable, accent color for Edit link |
| Comment edit saved (Turbo Stream) | 1280x720 | Light | In-place update works, form collapses, scroll position preserved |
| Comments section | 375x812 | Light | Content pushed right by sidebar, textarea very narrow |
| Comment edit form | 375x812 | Light | Form functional but cramped due to sidebar layout |

---

## Checklist Results

### Flow & Clarity
- [x] Primary action on each page is obvious (Save button is clearly styled)
- [ ] Error states visible and actionable -- **F2: validation errors redirect away from the form**
- [x] Success states confirmed with feedback (Turbo Stream replaces the card in place)
- [x] Multi-step flows feel connected (edit toggle -> form -> save -> updated card)
- [x] Empty states handled ("No comments yet." renders when no comments exist)

### Forms
- [ ] Labels present on all inputs -- **F3: edit textarea has no label**
- [x] Submit button clearly distinguishable (`ha-button-primary` for Save)
- [ ] Validation errors shown inline -- **F2: errors cause redirect, not inline display**
- [x] Form can be submitted with keyboard (Tab to textarea, type, Tab to Save, Enter)

### Navigation
- [x] Active page/section appears selected in sidebar
- [x] "Back to trip" link present on journal entry page
- [x] Page title reflects content (trip name as section, entry name as title)

### Authorization-Aware UI
- [x] Edit button only shown when `allowed_to?(:update?, @comment)` returns true
- [x] Delete button only shown when `allowed_to?(:destroy?, @comment)` returns true
- [x] No phantom buttons visible that lead to 403 errors
- [x] Comment form only shown when user has create permission

### Accessibility (basic)
- [x] Interactive elements reachable by keyboard
- [x] Buttons and links distinguishable by more than color (Save is a filled button, Edit/Delete are text links with different colors)
- [x] Text contrast sufficient in both light and dark mode
- [ ] Labels/aria-labels on form inputs -- **F3, F4**

### In-Place Updates (PWA)
- [x] Comment edit updates DOM in place without full page reload
- [x] Turbo Stream `replace` used for update action
- [x] Page maintains scroll position after successful edit
- [x] Edit form collapses after successful save (card replaced by Turbo Stream)
- [x] No visible page flash or full-page re-render on successful save

### Responsive
- [ ] Layout holds at 375px -- pre-existing sidebar issue (S4), not a Phase 9 regression
- [x] Touch targets adequate (Save button, Edit/Delete links are reasonably sized)

---

## Policy Logic Review

The operator precedence fix in all four policies is correct and important:

**Before (buggy):**
```ruby
superadmin? || (own_comment? && trip.commentable?)
```
This allowed superadmins to bypass trip state guards entirely (e.g., comment on archived trips).

**After (fixed):**
```ruby
(superadmin? || own_comment?) && trip.commentable?
```
Now superadmins must also respect trip state guards, which is the intended behavior.

---

## Summary

Phase 9 introduces a functional inline comment editing feature with correct authorization guards and proper Turbo Stream in-place updates. The core happy path works well. The main friction points are:

1. **Missing Cancel button** on the edit form (F1) -- easy fix
2. **Validation error handling** redirects away from the form (F2) -- moderate fix
3. **Missing accessible labels** on edit textarea (F3) -- easy fix

None of these block usability for sighted keyboard/mouse users, but F2 and F3 should be addressed before the PR is merged for a polished experience.
