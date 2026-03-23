# UX Review -- feature/export-architecture

Review date: 2026-03-23

## Changed Surfaces

Files modified (views and components):

- `app/views/exports/index.rb` -- export listing per trip
- `app/views/exports/new.rb` -- format selection form (Markdown ZIP / ePub)
- `app/views/exports/show.rb` -- export detail with status, format, requested by, file size
- `app/components/export_card.rb` -- card for export listing with status badge + actions
- `app/components/export_status_badge.rb` -- colored badge for pending/processing/completed/failed
- `app/views/trips/show.rb` -- added "Exports" link in header actions
- `app/components/sidebar.rb` -- added `exports` controller to Trips nav active check
- `app/views/export_mailer/export_ready.text.erb` -- email notification when export completes
- `app/views/trip_mailer/state_changed.text.erb` -- email notification on trip state change

---

## Broken (blocks usability)

### B1: No live status update on export show page

**Page:** Export show (`app/views/exports/show.rb`)

When a user requests an export, they are redirected to the show page which displays the current status (e.g., "Pending"). The export is generated asynchronously by `GenerateExportJob`. However, the show page has no mechanism to update when the job completes -- no Turbo Stream broadcast, no polling, no `<meta http-equiv="refresh">`. The user must manually refresh the browser to see the status change from "Pending" to "Completed" and to see the "Download" button appear.

This is a usability blocker because the user has no indication that anything is happening after the initial redirect, and no signal that the export is ready. The success flash toast ("Export requested. We'll notify you when it's ready.") is shown once and auto-dismissed after 4 seconds. After that, the page is static.

**Recommended fix:** Add a `<meta http-equiv="refresh" content="5">` to the show page when the export status is `pending` or `processing`. This is the simplest approach and avoids the complexity of ActionCable/Turbo Streams. Alternatively, add a Stimulus controller that polls the show endpoint every 5 seconds and replaces the page content via Turbo. The polling should stop once the status is `completed` or `failed`.

### B2: No default radio selection on export form -- submitting without selecting a format shows no inline error

**Page:** New export form (`app/views/exports/new.rb`)

Neither the "Markdown ZIP" nor "ePub" radio button is pre-selected. If the user clicks "Request Export" without selecting a format, the `Export.create!` call fails validation (format presence required), and the controller redirects back to the new page with `alert: "Could not create export."` The flash alert will appear as a toast, but it is generic and does not tell the user what went wrong ("format must be selected"). There is no inline validation error near the radio buttons.

Additionally, a user who does not scroll may miss the toast, which auto-dismisses after 4.5 seconds. They would see the same empty form again with no indication of what they did wrong.

**Recommended fix:** Pre-select the first radio button ("markdown") by adding `checked: true` to the first `render_format_option` call. This eliminates the empty-submission scenario entirely. Alternatively, add `required: true` to the radio buttons so the browser enforces selection before submission (native HTML5 validation).

---

## Friction (degrades experience)

### F1: Export card does not show requester name in list view

**Page:** Exports index (`app/views/exports/index.rb`, `app/components/export_card.rb`)

The export card shows "Markdown Export" and "Requested X ago" but does not show who requested the export. For superadmin users (who see all exports from all users), there is no way to distinguish whose export is whose without clicking into each one. The show page does display "Requested by" with the user's name, but the card does not.

**Recommended fix:** Add a line showing the requester's name in the card, e.g., "by Joel" under the "Requested X ago" text. Gate this behind a superadmin check if only superadmins see other users' exports.

### F2: Failed export provides no actionable information

**Page:** Export show (`app/views/exports/show.rb`)

When an export fails (the job catches an exception and sets `status: :failed`), the show page displays a "Failed" badge but provides no error message, no explanation of what went wrong, and no retry button. The user's only option is to navigate back and request a new export. The `exports` table has no column for storing error messages, so even the backend cannot surface a reason.

**Recommended fix (code-level):** Add an `error_message` text column to the `exports` table. In `GenerateExportJob`, set `@export.update(error_message: e.message)` in the rescue block. In the show view, display the error message when the status is `failed`, and offer a "Try again" link back to `new_trip_export_path(@trip)`.

### F3: "Exports" link on trip show is not gated behind authorization

**Page:** Trip show (`app/views/trips/show.rb`, line 58-62)

The "Exports" link is rendered unconditionally for all users who can view the trip. The `ExportPolicy#index?` requires `superadmin? || member?`, so a non-member viewing the trip (if that's possible) would see the link but get a 403 when clicking it. This is consistent with the "Checklists" and "Members" links, which also have no authorization gate on the trip show page. Noting for awareness rather than as a new bug -- this is an existing pattern.

**Recommended fix:** If non-members can view trips, wrap the "Exports" link with `if view_context.allowed_to?(:index?, @trip, with: ExportPolicy)`. Otherwise, document this as intentional.

### F4: Generic error message on export creation failure

**Page:** New export form (`app/views/exports/new.rb`) via controller redirect

When export creation fails (e.g., validation error), the controller redirects with `alert: "Could not create export."` This message is not specific enough. The user does not know whether the failure is due to a missing format, a server error, or a policy restriction.

**Recommended fix:** Pass the actual validation errors to the flash, e.g., `alert: errors.full_messages.to_sentence`. If the failure is a validation error on format, the message would read "Format can't be blank" which is actionable.

### F5: Export card layout may overflow at narrow viewports

**Page:** Exports index (`app/components/export_card.rb`)

The export card uses `flex items-center justify-between` with the format icon + text on the left and status badge + action buttons on the right. At narrow viewports (375px or below), the two sides may collide or overflow because there is no responsive breakpoint. The buttons use `text-xs` which helps, but when a "Download" button AND a "Details" button are both shown alongside a status badge, the right side has three inline elements.

**Recommended fix:** Add `flex-wrap` to the outer container or stack the actions below the title at narrow viewports using `sm:flex-row flex-col`.

---

## Suggestions (nice to have)

### S1: Selected radio option visual feedback

The format selection radio buttons use a card-like `label` with `hover:bg-[var(--ha-bg-muted)]` but have no visual indication of the _selected_ state beyond the native radio dot. Adding a border color change or background tint when selected (e.g., via CSS `:has(:checked)` or a Stimulus controller) would make the selection more obvious.

### S2: Export progress indication for "Processing" state

When an export is in the "Processing" state, the show page displays only the "Processing" status badge. Adding a spinner animation or pulsing indicator would communicate that work is actively happening.

### S3: Retry and delete actions for exports

There is no way to delete a failed or completed export, and no way to retry a failed export. Failed exports accumulate in the list with no cleanup mechanism. Consider adding a `destroy` action gated behind the export policy, and a "Retry" action that creates a new export with the same format.

### S4: Export format icon uses text abbreviation instead of a real icon

The export card's format icon renders "MD" or "EP" as plain text inside a styled span. Using an actual icon (e.g., a document icon for Markdown, a book icon for ePub) would be more visually consistent with the rest of the design system, which uses SVG icons throughout.

### S5: Page title not set for export pages

Export pages (index, new, show) do not set `content_for(:title)`, so the browser tab always shows "Catalyst". Setting descriptive titles like "Exports - Trip Name" would help users with multiple tabs open. Note: this is a codebase-wide pattern -- no views currently set page titles.

### S6: Email notification is text-only

The `export_ready` mailer sends a plain text email with a link. No HTML version is provided. Adding an HTML template with the app's branding would improve the email experience, though this is consistent with the existing `trip_mailer` pattern.

### S7: N+1 query potential on exports index

The exports index controller has a minor logic issue: line 10 assigns `@exports` for the current user, then line 12 conditionally overwrites it for superadmins. Both lines execute their queries even when the user is a superadmin. Consider using an early return or `if/else` to avoid the unnecessary first query.

---

## Checklist Results

### Flow & Clarity

- [x] Primary action on each page is obvious ("New export" on index, "Request Export" on form, "Download" on show)
- [ ] Error states not fully visible -- generic "Could not create export" toast, no inline errors on form (B2, F4)
- [x] Success states confirmed with flash toast ("Export requested. We'll notify you when it's ready.")
- [x] Empty state handled: "No exports yet." on index page
- [ ] Async flow lacks live feedback -- user must manually refresh to see status updates (B1)
- [x] Multi-step flow (select format -> submit -> view status -> download) is logically connected

### Forms

- [x] Labels present -- radio buttons are wrapped in `<label>` elements with descriptive text
- [x] Submit button clearly distinguishable (`ha-button-primary` for "Request Export")
- [ ] No default selection on radio buttons (B2)
- [x] Form can be submitted via keyboard (Tab through radio buttons + Enter on submit)
- [ ] No inline validation errors shown on the form page (B2, F4)

### Navigation

- [x] Sidebar correctly highlights "Trips" on export pages (`exports` controller included in active check)
- [x] "Back to trip" link present on exports index
- [x] "Back to exports" link present on export show and new pages
- [x] Page titles in PageHeader reflect content: section shows trip name, title shows "Exports" / "New Export" / "Markdown Export"
- [x] PageHeader section labels correctly show trip name as context

### Authorization-Aware UI

- [x] "New export" button on index is behind `allowed_to?(:create?, @trip, with: ExportPolicy)` check
- [x] "Download" button on card and show page is behind `completed? && file.attached?` check
- [x] Controller enforces authorization on all actions (`authorize!` calls)
- [x] Non-members cannot create exports (`ExportPolicy#create?` requires `member?`)
- [ ] "Exports" link on trip show is not gated (consistent with existing Checklists/Members pattern) (F3)

### Accessibility (basic)

- [x] Radio buttons are native `<input type="radio">` elements, keyboard accessible
- [x] Labels wrap radio buttons, enabling click-to-select on the full card area
- [x] Buttons and links distinguished by more than color (`ha-button` classes provide borders, backgrounds, hover states)
- [x] Text contrast uses design system CSS variables (`--ha-text`, `--ha-muted`) for both modes
- [x] Status badge uses both color AND text for state indication (colorblind-safe)
- [x] Export card format icon uses text content ("MD", "EP") that is inherently accessible

### Dark Mode

- [x] Export status badge has explicit `dark:` variants for all four states (amber, sky, emerald, red)
- [x] All text uses CSS variables (`--ha-text`, `--ha-muted`) that adapt to dark mode
- [x] Cards use `ha-card` class which adapts to dark mode
- [x] Format icon uses `var(--ha-accent)` with opacity, adapting to dark mode
- [x] Radio option cards use `var(--ha-border)` and `var(--ha-bg-muted)` which adapt to dark mode

### In-Place Updates (PWA)

- [ ] Export creation uses `redirect_to` (full page navigation), not Turbo Stream (acceptable for a creation flow)
- [ ] Export status does not update in place -- requires manual page refresh (B1)
- [x] Download action redirects to blob URL (standard file download pattern, no in-place update needed)

### Responsive

- [x] Page layouts use flex with gap spacing, no fixed widths
- [x] PageHeader uses `flex-col gap-4 sm:flex-row` for responsive header
- [x] Header actions use `flex flex-wrap gap-2` to wrap on narrow screens
- [ ] Export card may overflow at very narrow viewports (F5)
- [x] Radio option cards stack vertically in `space-y-4`, works at any width

---

## Screenshots Reviewed

Pages analyzed via web content inspection and thorough source code review:

1. Home page (`/`) -- app running, sidebar navigation visible, unauthenticated state
2. Trip show page (`/trips/:id`) -- "Exports" link present in header actions alongside Edit, Members, Checklists, Delete, Back to trips
3. Exports index (`/trips/:id/exports`) -- PageHeader with trip name as section, "Exports" as title, "New export" primary button (auth-gated), "Back to trip" secondary button, empty state card "No exports yet."
4. New export form (`/trips/:id/exports/new`) -- PageHeader with "New Export" title, radio card selection for Markdown ZIP and ePub, "Request Export" submit button, "Back to exports" secondary link
5. Export show (`/trips/:id/exports/:id`) -- PageHeader with format name as title, "Download" primary button (conditional), "Back to exports" secondary button, detail card with Status badge, Format, Requested by, File size
6. Export card component -- format icon (MD/EP), title, time ago, status badge, Download + Details buttons
7. Sidebar navigation -- Trips nav item correctly highlighted on all export pages

Note: `agent-browser` tool was not available in this session. Analysis was performed via `WebFetch` page inspection and comprehensive source code review. All rendered HTML structures were verified against component source code and compared against existing patterns (checklists, trip memberships) for consistency.

---

## Summary

The Phase 6 export UI is well-structured and follows existing design patterns closely. The component decomposition (`ExportCard`, `ExportStatusBadge`) matches the project's conventions (`ChecklistCard`, `TripStateBadge`). Navigation integration is correct, authorization gates are properly applied, empty states are handled, and dark mode support is complete.

The primary usability concern is the async export flow (B1): after requesting an export, the user lands on a static show page with no live status updates. Since the export is generated by a background job, the user has no way to know when it finishes without manually refreshing. A simple `<meta refresh>` or polling Stimulus controller would resolve this.

The secondary concern is the form's lack of a default radio selection (B2), which allows empty submissions that produce a generic error message with no inline feedback.

Friction items F1-F5 are quality-of-life improvements that would polish the experience but do not block core functionality. Suggestions S1-S7 are enhancements for future consideration.
