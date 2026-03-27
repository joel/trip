# UX Review -- feature/catalyst-glass-design-system

**Date:** 2026-03-27
**Reviewer:** Claude Opus 4.6 (agent-browser + code inspection)
**Branch:** feature/catalyst-glass-design-system
**Scope:** Phases 0--10 -- Catalyst Glass Design System overhaul (glassmorphism, editorial typography, tonal layering, mobile navigation)

---

## Summary

The Catalyst Glass Design System implements a comprehensive visual overhaul across 30+ view and component files. The design system introduces M3-inspired tonal layering, editorial typography (Space Grotesk headlines, Inter body), glassmorphism effects, gradient buttons, magazine-style journal layouts, and a mobile bottom navigation bar. The implementation is solid overall, with well-structured CSS custom properties and consistent token usage. Several UX issues were identified, primarily around navigation state during the auth flow and content redundancy on detail pages.

---

## Broken (blocks usability)

### 1. Sidebar shows admin navigation links to unauthenticated users during login flow

**Page:** `/login` (after email is recognized, on the "Choose a sign-in method" page)
**What happens:** When a user enters their email on the login page and gets redirected to the sign-in method chooser, the sidebar renders as if the user is authenticated -- showing "Users", "Requests", "Invitations", and "New user" links. These links are visible even though the user has NOT completed authentication.
**Root cause:** The Rodauth session appears to be partially initialized after email recognition (`skip_login_field_on_login?` is true), which causes `allowed_to?(:index?, User)` and `allowed_to?(:index?, AccessRequest)` checks in `sidebar.rb:80-104` to pass. The `logged_in?` check on line 71 may also be returning true prematurely.
**Impact:** Users see admin-level navigation they should not see. While clicking these links may still be blocked by controller-level authorization, the leaked navigation is a security perception issue and could expose internal URL structures.
**Recommended fix:** Ensure sidebar admin links are gated on `logged_in?` AND the user being fully authenticated (not just email-recognized). Consider adding a `fully_authenticated?` guard that checks `rodauth.logged_in?` AND excludes the login/email-auth flow state.

### 2. Flash message "Login recognized, please enter your password" is misleading for passwordless auth

**Page:** `/login` (after email recognition)
**What happens:** The flash notice says "Login recognized, please enter your password" but the app uses passwordless authentication (passkeys and magic links). There is no password field.
**Impact:** Users see a confusing message that contradicts the actual UI (which shows "Use a passkey" or "Send a sign-in link"). This is likely a default Rodauth flash message that was not customized.
**Recommended fix:** Override the Rodauth `require_login_notice_flash` or equivalent configuration to say something like "Email recognized. Choose how to sign in." or remove the flash entirely since the page itself already explains the options.

### 3. No feedback after clicking "Send Login Link Via Email"

**Page:** "Choose a sign-in method" page
**What happens:** After clicking the "Send Login Link Via Email" button, the page does not change visually. There is no toast notification, no flash message, and no visual confirmation that the email was sent. The email IS sent (confirmed via server logs), but the user has no way to know.
**Impact:** Users will click the button multiple times thinking it did not work, or will not know to check their email.
**Recommended fix:** After the magic link is sent, redirect to a confirmation page or show a flash toast: "A sign-in link has been sent to your email. Check your inbox." Alternatively, show inline text replacing the button.

---

## Friction (degrades experience)

### 4. Journal entry detail page shows description text twice

**Page:** `/trips/:id/journal_entries/:id`
**Component:** `app/views/journal_entries/show.rb`
**What happens:** The `render_entry_details` method (lines 81-96) renders the `description` field (a truncated plain-text version) in a card, and then `render_body` (lines 98-103) renders the full `body` rich text below it. Since `description` is auto-generated as a truncation of `body`, the same content appears twice -- once as a summary and once as the full text.
**Impact:** Looks like a rendering bug to users. The description adds no value when the full body is already shown.
**Recommended fix:** Either (a) skip `render_entry_details` when `body` is present (since body contains the same content in full), or (b) only show `location_name` in the detail card and omit the `description` field entirely on the show page.

### 5. Logged-in home page lacks trip summary on dashboard

**Page:** `/` (authenticated)
**Component:** `app/views/welcome/home.rb`
**What happens:** The logged-in dashboard shows a welcome message, "New Trip" CTA, and two info cards (Team, Security). It only shows an "active trip" card if there is a trip in `started` state. For the admin user who has 5 trips (none currently "started"), the dashboard shows no trip content at all -- just the two action cards.
**Impact:** Users with no active trip see a sparse dashboard with no way to quickly access their trips without using the sidebar. The "Trips" link in the sidebar is the only path, which is not discoverable for new users.
**Recommended fix:** Add a "Recent trips" or "Your trips" section below the quick action cards that shows the 3 most recent trips (regardless of state) with a "View all" link to `/trips`.

### 6. "Create account" sidebar link redirects to home without explanation

**Page:** Sidebar "Create account" link (logged out)
**What happens:** Clicking "Create account" in the sidebar redirects to the home page (`/`) without any flash message explaining why account creation is not available. The app is invite-only, so direct account creation is disabled.
**Impact:** Users think the link is broken. They get silently redirected with no feedback.
**Recommended fix:** Either (a) hide the "Create account" link from the sidebar when self-registration is disabled, or (b) redirect to `/create-account` with a flash message: "Account creation requires an invitation. Request access to get started." linking to the access request form.

### 7. "Finish signing in" page has minimal UX context

**Page:** `/email-auth?key=...`
**What happens:** After clicking the magic link in the email, users see a "Finish signing in" page with just a "Login" button and no other context. The page lacks a heading section label (unlike other pages) and does not explain what is happening.
**Impact:** Users may be confused about why they need to click another button after already clicking the email link.
**Recommended fix:** Add a brief explanation: "Click below to complete your sign-in." and consider auto-submitting the form with JavaScript to reduce friction.

### 8. Trip hero cover uses gradient placeholder instead of actual trip images

**Pages:** Trip detail (`/trips/:id`), Trip cards on index and dashboard
**Component:** `app/views/trips/show.rb:27-37`, `app/components/trip_card.rb:27-36`
**What happens:** The trip hero cover and card covers render a gradient placeholder (`bg-gradient-to-br from-[var(--ha-primary)] to-[var(--ha-primary-container)]`) instead of actual trip photos. Even though journal entries have attached images that could be used as trip covers.
**Impact:** All trip cards and hero sections look identical (same gradient), reducing visual distinction between trips. The magazine-style editorial layout benefits from real imagery.
**Recommended fix:** Use the first attached image from the trip's journal entries as the cover image, falling back to the gradient when no images exist.

---

## Suggestions (nice to have)

### 9. Mobile bottom nav could show "Requests" for admin users

The mobile bottom nav shows HOME, TRIPS, USERS, PROFILE for logged-in admin users. The "Requests" and "Invitations" admin pages are only accessible through the desktop sidebar, making them unreachable on mobile without manually typing the URL. Consider adding a "More" or overflow menu for admin-specific links.

### 10. Card hover lift effect on non-interactive cards

All `.ha-card` elements have a hover lift effect (`:hover { transform: translateY(-4px) }`). On information-display cards (like the trip info card on the detail page, or the user profile card on the account page), this creates a false affordance -- the card lifts as if it is clickable but clicking does nothing.
**Recommended fix:** Only apply the hover lift on cards that are actually clickable or contain primary action links. Use a `.ha-card-static` variant for display-only cards.

### 11. Prefers-reduced-motion could also disable card hover transforms

The CSS includes `@media (prefers-reduced-motion: reduce)` that disables animations, but the card hover `transform: translateY(-4px)` is applied via a `transition`, not an animation, and is not covered by this media query.

### 12. Input focus state uses hard-coded color instead of CSS variable

In `application.css:251`, the `.ha-input:focus` border uses `rgba(0, 102, 138, 0.15)` which is a hard-coded value matching `--ha-primary` in light mode. The dark mode override on line 256 uses `rgba(123, 208, 255, 0.15)` matching the dark primary. Consider using `color-mix()` or a dedicated `--ha-ring-border` variable for consistency.

### 13. Background decorations (gradient blobs) are pleasant but may impact performance

The `render_background_decorations` method in `application_layout.rb:67-75` renders two large blurred gradient circles (`blur-[120px]` and `blur-[100px]`). These are `position: fixed` with high blur values. On lower-end devices, CSS blur on large elements can cause GPU compositing overhead.
**Suggestion:** Consider adding `will-change: transform` to these elements or hiding them on mobile via `hidden md:block`.

### 14. Access Request form placeholder uses plain text instead of label association

The access request form (`access_request_form.rb:18`) uses `placeholder: "your@email.com"` on the email field. While a label IS present, the placeholder could be confusing for screen reader users who may hear both the label and placeholder announced. Consider removing the placeholder since the label "Email" is sufficient.

---

## Checklist Results

### Flow and Clarity
- [x] Primary action on each page is obvious (gradient CTA buttons stand out well)
- [x] Error states visible and actionable (Rodauth flash errors, form validation with inline errors)
- [ ] Success states confirmed with feedback -- **FAIL**: Magic link send has no confirmation
- [x] Multi-step flows feel connected (login -> sign-in method -> magic link flow is logically structured)
- [x] Empty states handled ("No journal entries yet", "No comments yet")

### Forms
- [x] Labels present on all inputs (label elements with proper association)
- [x] Submit button clearly distinguishable (`ha-button-primary` gradient vs `ha-button-secondary`)
- [x] Validation errors shown inline (aria-invalid + describedby pattern used consistently)
- [x] Forms submittable with keyboard (standard form elements, Tab + Enter works)

### Navigation
- [ ] Active page/section appears selected in sidebar -- **PARTIAL**: Active state works for main sections but not all sub-pages
- [x] "Back to ..." links present (trip detail has "Back to trips", journal entry has "Back to trip")
- [x] Page titles reflect content (section overlines like "TRIPS", "DIRECTORY", "ADMINISTRATION")
- [x] PageHeader section/title labels make sense

### Authorization-Aware UI
- [ ] Action buttons hidden for users without permission -- **PARTIAL FAIL**: Admin nav links leak in sidebar during login flow
- [x] Edit/Delete buttons properly gated by `allowed_to?` checks
- [x] Members link visible to viewers (intentional)

### Accessibility (basic)
- [x] Interactive elements reachable by keyboard
- [x] Buttons and links distinguishable by more than color (gradient vs flat, size differentiation)
- [x] Text contrast sufficient in light mode (dark text on light backgrounds)
- [x] Text contrast sufficient in dark mode (light text on dark backgrounds)
- [x] Images have alt text (`alt: "#{@entry.name} - photo #{index + 1}"`)
- [x] Navigation landmarks present (`aria_label: "Main navigation"`, `aria_label: "Mobile navigation"`, `aria_label: "Mobile header"`)
- [x] Focus-visible styles defined (`.ha-button:focus-visible { outline: 2px solid var(--ha-ring) }`)

### Responsive
- [x] Layout holds at 375px width without horizontal scrolling
- [x] Sidebar hidden on mobile (`hidden md:flex`), bottom nav shown (`md:hidden`)
- [x] Mobile top bar shows correctly with brand and avatar/sign-in link
- [x] Touch targets adequate (bottom nav tabs have `px-3 py-2` padding, buttons have `0.75rem 1.5rem`)

### PWA and In-Place Updates
- [ ] Not fully testable in this review (would require interactive login session testing)
- [x] Service worker registered (confirmed in server logs)
- [x] Turbo Stream used for comments (form_with default)
- [x] `data: { turbo: false }` correctly used on auth forms to prevent Turbo interference

---

## Screenshots Reviewed

| Page | Viewport | Mode | Status |
|------|----------|------|--------|
| Home (logged out) | 1280x720 | Light | Verified |
| Home (logged out) | 1280x720 | Dark | Verified |
| Home (logged out) | 375x812 | Light | Verified |
| Home (logged in) | 1280x720 | Light | Verified |
| Home (logged in) | 375x812 | Light | Verified |
| Login | 1280x720 | Light | Verified |
| Login | 1280x720 | Dark | Verified |
| Login | 375x812 | Light | Verified |
| Create Account | 1280x720 | Light | Verified (redirects to home) |
| Request Access | 1280x720 | Light | Verified |
| Choose Sign-in Method | 1280x720 | Light | Verified |
| Finish Signing In | 1280x720 | Light | Verified |
| Trips Index | 1280x720 | Light | Verified |
| Trips Index (full page) | 1280x720 | Light | Verified (all 5 trips visible) |
| Trip Detail (Japan) | 1280x720 | Light | Verified |
| Trip Detail (full page) | 1280x720 | Light | Verified (hero + 5 entries) |
| Journal Entry Detail | 1280x720 | Mixed | Verified (images, reactions, comments) |
| Users Index | 1280x720 | Light | Verified |
| Account | 1280x720 | Light | Verified |
| Access Requests (admin) | 1280x720 | Light | Verified |
| Invitations (admin) | 1280x720 | Light | Verified |

---

## Design System Token Audit

### Implemented correctly
- M3-style tonal surface hierarchy (6 surface levels: `surface`, `surface-low`, `surface-container`, `surface-high`, `surface-highest`, `surface-variant`)
- Primary/Secondary/Tertiary color roles with container variants
- Dark mode fully mapped with inverted luminosity
- Semantic error tokens (`--ha-error`, `--ha-error-container`)
- Panel tokens for sidebar (`--ha-panel`, `--ha-panel-strong`, `--ha-panel-text`, `--ha-panel-muted`)
- Glassmorphism utility class (`ha-glass`) with light/dark variants
- Button system: primary (gradient), secondary (tonal), danger
- Input system: `ha-input` with tonal background, ghost border on focus
- Card system: `ha-card` with ambient shadow, hover lift
- Typography: Space Grotesk for headlines, Inter for body, JetBrains Mono for code
- Animation system: `ha-fade-in`, `ha-rise` with `prefers-reduced-motion` support

### Missing or incomplete
- No `--ha-success` or success container token (uses hard-coded emerald in `RodauthFlash`)
- No `--ha-warning` token
- No `ha-card-static` variant for non-interactive cards
- The `ha-nav` class sets `width: 16rem` but this is not exposed as a variable

---

## Component Quality Summary

| Component | Token Usage | A11y | Responsive | Grade |
|-----------|-------------|------|------------|-------|
| Sidebar | Excellent | Good (aria-label) | Good (hidden md:flex) | A |
| MobileTopBar | Excellent | Good (aria-label) | Good (md:hidden) | A |
| MobileBottomNav | Excellent | Good (aria-current) | Good (md:hidden) | A- |
| PageHeader | Excellent | Good | Good | A |
| TripCard | Excellent | Fair (no alt on gradient) | Good | A- |
| TripStateBadge | Excellent | Good | N/A | A |
| JournalEntryCard | Good | Good (alt text) | Good | A |
| UserCard | Excellent | Good (truncate) | Good | A |
| ChecklistCard | Excellent | Good | Good | A |
| CommentCard | Good | Good (sr-only label) | Good | A |
| RodauthLoginForm | Good | Good (aria-invalid) | Good | A |
| RodauthFlash | Fair (hard-coded colors) | Good | Good | B+ |
| AccessRequestForm | Good | Good | Good | A |
| ApplicationLayout | Excellent | Good | Good | A |

---

## Priority Actions

1. **Fix (before PR):** Investigate and fix sidebar admin link visibility during the login flow (#1)
2. **Fix (before PR):** Add feedback after magic link send (#3)
3. **Fix (before PR):** Customize Rodauth flash message for passwordless context (#2)
4. **Defer (follow-up):** Address journal entry description duplication (#4)
5. **Defer (follow-up):** Add recent trips section to dashboard (#5)
6. **Defer (follow-up):** Use real images for trip covers (#8)
7. **Defer (follow-up):** Hide or redirect "Create account" link when disabled (#6)
