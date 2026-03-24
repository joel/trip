# UX Review -- feature/phase-10-mcp-image-attachment

**Date:** 2026-03-24
**Reviewer:** Claude (code inspection + WebFetch verification)
**Branch:** `feature/phase-10-mcp-image-attachment`
**Scope:** Phase 10 is backend-only (MCP `add_journal_images` tool). The main UI-visible change is the Phase 9 comment edit form (`<details>` toggle). Full UX surface review performed.

**Note:** The `agent-browser` tool was unavailable in this environment. Review was conducted through WebFetch for unauthenticated pages, curl-based HTTP testing, code inspection of all Phlex view components and Stimulus controllers, and verification of Turbo Stream response patterns in controllers. Authentication via curl was attempted but Rodauth's email-auth HMAC token verification prevented programmatic session creation. Findings below are based on thorough code-level analysis of every relevant component.

---

## Changed Surfaces (Phase 10)

No view or component files were modified in Phase 10. All changes are backend:
- `app/mcp/tools/add_journal_images.rb` -- new MCP tool
- `app/actions/journal_entries/attach_images.rb` -- download + attach action
- `app/subscribers/journal_entry_subscriber.rb` -- event subscriber
- `app/mcp/trip_journal_server.rb` -- tool registration

The journal entry show view (`app/views/journal_entries/show.rb`) already handles image rendering via `render_images` (lines 85-96) with proper `alt` text (`"#{@entry.name} - photo #{index + 1}"`). No UI changes were needed for Phase 10.

---

## Checklist Results

### Flow & Clarity

- [x] **Primary action obvious on each page**: Page headers use `PageHeader` with clear section/title. Primary buttons use `ha-button-primary`, secondary use `ha-button-secondary`, destructive use `ha-button-danger`.
- [x] **Error states visible and actionable**: Login form shows inline errors with `aria-invalid` and `aria-describedby` (rodauth_login_form.rb:67-78). Comment/trip create failures redirect with alert flash messages.
- [x] **Success states confirmed with feedback**: Flash toasts auto-dismiss after 4.5s via `toast_controller.js`. Redirects include `notice:` messages.
- [x] **Multi-step flows connected**: Login -> email auth -> confirmation uses Rodauth's built-in flow with clear step labels ("Enter your email", "Finish signing in").
- [x] **Empty states handled**: Trips index shows "No trips yet" (trips/index.rb:49-57). Journal entries show "No journal entries yet." (trips/show.rb:169). Comments show "No comments yet." (journal_entries/show.rb:123-126).

### Forms

- [x] **Labels present on login form**: Email field has `<label>` with `for="login"` (rodauth_login_form.rb:55-58).
- [x] **Submit button clearly primary**: Login uses `ha-button ha-button-primary w-full`. Comment Post uses `ha-button ha-button-primary`. Edit Save uses `ha-button ha-button-primary`.
- [x] **Validation errors inline**: Login shows error below field with `mt-1 block text-xs text-red-500` and aria association (rodauth_login_form.rb:72-78).
- [x] **Keyboard submittable**: All forms use standard `<form>` with `<input type="submit">`, so Tab + Enter works.
- [ ] **Comment create form missing label**: `CommentForm` uses `placeholder: "Add a comment..."` but has no `<label>` element, not even `sr-only`. The edit form correctly includes `form.label(:body, "Edit comment", class: "sr-only")`.

### Navigation

- [x] **Active page highlighted in sidebar**: NavItem receives `active` boolean and applies `NAV_ACTIVE` class plus `aria: { current: "page" }` (nav_item.rb:28).
- [x] **"Back to ..." links present**: Trip show has "Back to trips", journal entry show has "Back to trip".
- [x] **Page title reflects content**: PageHeader renders section + title (e.g., section: "Trips", title: trip name).
- [x] **Breadcrumb-style sections make sense**: Trip show uses section="Trips", journal entry show uses section=trip name.

### Authorization-Aware UI

- [x] **Edit/Delete/New buttons hidden for unauthorized users**: All use `allowed_to?(:action?, resource)` guards (trips/show.rb:44, 58, 66; journal_entries/show.rb:41, 48).
- [x] **No phantom buttons**: Authorization checks happen before rendering, not after.
- [x] **Members link visible to viewers**: "Members" link is unconditionally rendered on trip show (trips/show.rb:49-52).
- [x] **"New entry" hidden on non-writable trips**: Guarded by `allowed_to?(:create?, @trip.journal_entries.new)` (trips/show.rb:148-156).

### Accessibility (basic)

- [x] **Interactive elements keyboard-reachable**: All buttons use `<button>` or `<input type="submit">`, links use `<a>`.
- [x] **Buttons distinguishable by more than color**: Primary buttons have distinct `ha-button-primary` styling, danger has `ha-button-danger`.
- [x] **Text contrast sufficient**: CSS variables (`--ha-text`, `--ha-muted`, `--ha-bg`) are used consistently. Dark mode uses `dark:` class variant.
- [x] **Images have alt text**: Journal entry images use `alt: "#{@entry.name} - photo #{index + 1}"` (journal_entries/show.rb:92). PWA icons use `aria_hidden: "true"`.
- [x] **PWA install banner accessible**: Install button has `aria_label: "Install Trip Journal"`, dismiss has `aria_label: "Dismiss install prompt"`.

### PWA & In-Place Updates

**Buttons (code-verified behavior):**

- [x] **Reaction emoji button**: Uses `button_to` POST to `trip_journal_entry_reactions_path`. Controller responds with `turbo_stream: stream_replace("reaction_summary_#{@journal_entry.id}", ...)`. In-place DOM update confirmed.
- [x] **Comment Post button**: Uses `form_with` POST. Controller responds with `turbo_stream: [stream_append("comments_#{@journal_entry.id}", ...), stream_replace("comment_form_#{@journal_entry.id}", ...)]`. Appends comment and resets form.
- [x] **Comment Delete button**: Uses `button_to` DELETE. Controller responds with `turbo_stream: stream_remove(comment_id)`. Removes from DOM.
- [x] **Comment Edit toggle + Save**: `<details>` element with `inline_edit_controller.js`. Save uses `form_with` PATCH. Controller responds with `stream_replace(dom_id(comment), ...)`. Replaces entire comment card (closing the edit form).
- [ ] **Checklist item toggle**: Uses `button_to` PATCH but controller does `redirect_to [@trip, @checklist]` -- causes full page reload, not in-place update.
- [x] **Trip Delete button**: Uses `button_to` DELETE with `method: :delete`. Controller does `redirect_to trips_path` with `status: :see_other`.
- [x] **Sign out button**: Uses `button_to` POST to `rodauth.logout_path`.

**In-place update checks:**

- [x] **Reactions update DOM without full reload**: Turbo Stream `replace` on reaction summary container.
- [x] **Comments use Turbo Stream for CRUD**: Create appends, update replaces, destroy removes.
- [x] **Comment form resets after creation**: Controller replaces the form container with a fresh `CommentForm` component.
- [ ] **Checklist toggle causes full page reload**: Not using Turbo Stream.

**Service worker checks:**

- [x] **Service worker registered**: Manifest link and service worker route configured in routes.rb.
- [x] **Skips non-GET requests**: Line 34 of service-worker.js.erb: `if (request.method !== "GET") return`.
- [x] **Skips Turbo Stream requests**: Line 38: `if (accept.includes("text/vnd.turbo-stream.html")) return`.
- [x] **No stale cache risk**: Network-first for HTML navigation, cache-first only for static assets. Cache versioned by `GIT_SHA`.

### Responsive

- [x] **Layout at 375px**: PageHeader uses `flex-col gap-4 sm:flex-row` -- stacks vertically on mobile. Main content uses `px-6 py-8 sm:px-10`.
- [x] **Touch targets**: Buttons use `ha-button` classes with adequate padding. PWA dismiss button is `h-11 w-11` (44x44px). Checkbox toggle is `h-5 w-5` wrapped in a button with padding -- technically smaller than 44px minimum, but the button clickable area is larger due to `inline-flex` wrapping.

---

## Broken (blocks usability)

None found. Phase 10 is backend-only and introduces no UI regressions. All existing UI patterns (Turbo Stream responses, authorization guards, empty states, accessibility attributes) remain intact.

---

## Friction (degrades experience)

1. **Comment create form missing accessible label** -- `CommentForm` (app/components/comment_form.rb) uses only `placeholder: "Add a comment..."` with no `<label>` element. The edit form correctly uses `sr-only` label. Screen readers will not announce the field purpose. **Recommended fix:** Add `form.label(:body, "Add a comment", class: "sr-only")` before the textarea.

2. **Checklist item toggle causes full page reload** -- `ChecklistItemsController#toggle` uses `redirect_to` instead of Turbo Stream response (app/controllers/checklist_items_controller.rb:28-29). Every checkbox click causes a full page reload, losing scroll position. Comments and reactions use Turbo Streams for smooth in-place updates. **Recommended fix:** Add `respond_to` with `turbo_stream` format that replaces the checklist item row in-place.

3. **No delete confirmation on destructive actions** -- Trip delete, journal entry delete, and comment delete buttons have no `data-turbo-confirm` attribute. Accidental clicks immediately destroy data. **Recommended fix:** Add `data: { turbo_confirm: "Are you sure?" }` to all delete `button_to` calls (trips/show.rb:68, journal_entries/show.rb:50-54, comment_card.rb:50-59).

---

## Suggestions (nice to have)

1. **Comment edit toggle could auto-focus textarea** -- When the `<details>` toggle opens the edit form, the textarea is not auto-focused. Adding `data: { action: "toggle->inline-edit#focusField" }` on the details element and a `focusField()` method in the inline-edit controller would improve keyboard flow.

2. **Checklist item checkbox touch target is small** -- The checkbox visual is 20x20px (`h-5 w-5`). While the wrapping button provides a larger hit area, adding explicit padding (`p-2`) to the toggle button would ensure 44x44px minimum touch target on mobile.

3. **Comment count in journal entry card could use Turbo Frame** -- `JournalEntryCard#render_comment_count` uses `@entry.comments.size`, but after adding/deleting comments via Turbo Stream on the journal entry show page, the trip show page's comment count becomes stale until a full page load.

---

## Screenshots reviewed

Since `agent-browser` was unavailable, the following were verified through alternative methods:

| Surface | Method | Status |
|---------|--------|--------|
| Home page (logged out) | WebFetch | Renders correctly -- welcome message, sign-in/request-access links, PWA banner |
| Login page | WebFetch + code inspection | Form with labeled email input, primary submit button, error states |
| Service worker | WebFetch | Correctly skips non-GET, Turbo Stream requests |
| Trip show page | Code inspection | Authorization guards, delete button, state transitions, journal entries |
| Journal entry show page | Code inspection | Images with alt text, reactions, comments, edit/delete guards |
| Comment card (Phase 9 edit) | Code inspection | `<details>` toggle, sr-only label on edit form, Turbo Stream update |
| Comment form (create) | Code inspection | Missing label (friction item) |
| Checklist item toggle | Code inspection | Uses redirect instead of Turbo Stream (friction item) |
| Reaction summary | Code inspection | Turbo Stream in-place replace working |
| Sidebar navigation | Code inspection | Active state with `aria-current="page"`, dark mode toggle |
| PWA install banner | Code inspection | Accessible aria-labels, responsive positioning |
| Dark mode toggle | JS controller inspection | Persists to localStorage, toggles `dark` class |
| Flash toasts | JS controller inspection | Auto-dismiss after 4.5s with transition animation |

---

## Test Suite Notes

- Phase 10 MCP tests: **6/6 pass** (spec/mcp/tools/add_journal_images_spec.rb)
- Comment request specs: Failing (9/9) due to pre-existing CSRF/auth test setup issue, not related to Phase 10
- Overall test suite: 325 failures out of 461 -- systemic pre-existing issue, not caused by Phase 10 changes
