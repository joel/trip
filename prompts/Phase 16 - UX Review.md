# Phase 16 — UX Review (PR #103)

**Branch:** `feature/phase16-onboarding-improvements`
**Reviewer:** ux-review skill (live agent-browser walk-through)
**App URL:** `https://catalyst.workeverywhere.docker`
**Date:** 2026-04-18

---

## Summary of Changed Surfaces

Phase 16 modifies the following user-visible surfaces:

| File | Change |
|---|---|
| `app/views/welcome/home.rb` | Logged-out hero now shows a single "Request an invitation" card (removed sign-in card) |
| `app/misc/rodauth_main.rb` | `before_login_route` redirects unknown-email logins to `/` with flash; `validate_invitation_token` redirects to `/` for manual `/create-account` with no valid token; invited signups skip the `verify_account` step and auto-log-in; custom `create_account_notice_flash` for invited users |
| `app/models/access_request.rb` | Normalizes email to lowercase; `email_not_already_active` and `email_not_already_registered` validations on `create` |
| `app/actions/access_requests/submit.rb` | Handles `RecordNotUnique` race condition with duplicate email error |
| `db/migrate/…_add_unique_index_on_active_access_request_email.rb` | Unique index on `(email, status)` for active rows |

The review walked every flow from the user's perspective in both light and dark mode, and at both desktop (1280x800) and mobile (393x852) viewports, using live agent-browser screenshots as the primary source of truth.

---

## Flow-by-Flow Findings

### Flow 1 — First-time visitor lands on `/` (logged out)

**Screenshots:** `/tmp/phase16-ux/01-home-logged-out-light.png`, `/tmp/phase16-ux/32-desktop-dark-home.png`, `/tmp/phase16-ux/26-mobile-home.png`, `/tmp/phase16-ux/30-mobile-dark-home.png`, `/tmp/phase16-ux/34-logged-out-home-fresh.png`

**What the user sees (desktop):**
- Big "Welcome to Catalyst" heading, left-aligned
- Subheading "Your collaborative trip journal."
- Centred card: "ACCESS / Request an invitation / This is an invite-only app. Request access to get started. / [Request Access]"
- Sidebar: Overview, Dark mode, Sign in, Create account

**Findings:**

- VERIFIED OK: Single centred card layout replaces the previous dual-panel confusion. Card is proportionally sized (max-w-md), centred via `mx-auto`, and reads clearly.
- VERIFIED OK: Dark mode renders correctly.
- VERIFIED OK: Mobile layout is clean, card fits within viewport, Request Access button is ~44px tall.
- HIGH - Visual alignment mismatch: The "Welcome to Catalyst" headline is flush-left inside `max-w-5xl` but the card is `max-w-md mx-auto` (centred). At 1280px, this creates a perceptible disconnect: the headline reads as a page title but the card floats to the right of the sidebar, visually unanchored. Consider either (a) aligning the card to the left under the headline, or (b) centring the headline too.
- HIGH - Trap link in sidebar ("Create account"): The sidebar shows a "Create account" link that points to `/create-account`. After Phase 16 changes, this URL always redirects to `/` with an "Invitation required" flash for anonymous users. The link is still useful for users with an invitation URL, but for the general visitor it is a dead-end. Recommendation: hide `Create account` from the sidebar when the user is logged out, or change its label to "I have an invitation" and link to `/request-access` instead.
- MEDIUM - "Profile" label on mobile bottom nav is misleading: For logged-out users, the bottom mobile nav shows "Profile" which links to `/login`. "Profile" suggests an existing account. Rename to "Sign in" in logged-out state, matching the desktop sidebar label.

### Flow 2 — Unknown email posted to `/login`

**Screenshots:** `/tmp/phase16-ux/14-immediate-screenshot.png` (flash visible), `/tmp/phase16-ux/03-login-unknown-email-redirect.png` (flash auto-dismissed)

**Flow observed:**
1. Visit `/login`.
2. Type `ghost@example.com`.
3. Submit.
4. Server returns `302 -> /` with alert flash "Invitation required. Request access below."
5. Browser loads `/`; toast appears top-right; auto-dismisses after 4.5 s.

**Findings:**

- VERIFIED OK: Redirect works, flash copy is clear and directs the user below.
- VERIFIED OK: No generic rodauth "no matching login" error — Phase 16's `before_login_route` hook intercepts cleanly.
- HIGH - Toast auto-dismisses before the "Request Access" CTA has finished its slide-in animation: The `access_card` div uses `ha-rise` with `animation-delay: 160ms`, and the toast `timeoutValue` is 4500 ms. A user whose attention is on the headline (which loads first) may not see the card finish animating in until the toast is already fading out. A more deliberate choreography would (a) increase the alert toast timeout to ~7 s for actionable errors, or (b) use a persistent banner above the Request Access card instead of a transient toast.
- HIGH - Toast text "Request access below" is positionally inaccurate at desktop widths: The toast is top-right; the CTA card is centred below the main column. At 1280 px it's obvious the card is in front of / below the toast. But at larger viewports or with the sidebar collapsed, "below" could read as ambiguous. Consider rewording to "Tap Request Access to get started." which is CTA-relative rather than spatial.
- MEDIUM - No inline reinforcement of the flash on the destination page: Once the toast fades, the user sees a generic "Welcome to Catalyst" page with no visible hint why they arrived there. If they didn't catch the toast, they may wonder why their login attempt silently landed them on the homepage. Consider adding a dismissible persistent banner (Stimulus controller with localStorage) above the Request Access card that only appears when `session[:onboarding_hint] == "login_without_account"`.

### Flow 3 — Manual `/create-account` GET (no token)

**Screenshots:** `/tmp/phase16-ux/15-create-account-no-token.png`, `/tmp/phase16-ux/16-create-account-no-token-submitted.png`

**Flow observed:**
1. Visit `/create-account` directly.
2. Page renders a standard "Create account" form with email field and "Create Account" submit.
3. User types `no-token-user@example.com`, clicks Create Account.
4. POST returns `302 -> /` with the same "Invitation required. Request access below." flash.

**Findings:**

- CRITICAL - GET `/create-account` without token is a user-facing honeypot: The page renders normally with no upfront warning that submission will fail. Copy reads "Sign up with your email and we will verify it before you log in." — which is a false promise. Users type their email, click Create Account, and only THEN learn they need an invitation. This is a significant UX failure because:
  - Users invest effort (typing email) that the system already knows will fail.
  - The copy creates the expectation of open signups, directly contradicting the app's invite-only policy.
  - The redirect is silent unless the user catches the 4.5 s toast.

  Recommended fix options (pick one):
  - Best: Redirect GET `/create-account` (when no `invitation_token` param is present) to `/` with the flash immediately - don't render the form at all.
  - Acceptable: Keep the form but replace its copy with "This is an invite-only app. Please request access via /request-access, or use your invitation link." and either hide or disable the Create Account button.
  - Minimum: Prominent banner at the top of the form: "Invitation required. If you received an invitation, click the link in your email. Otherwise request access."
- HIGH - Misleading copy for legitimate invited users: Even for valid-token flows, the heading "Create account" and subheading "Sign up with your email and we will verify it before you log in" are wrong. No verification happens (Phase 16 explicitly skips `verify_account` for invited users). Copy should be: "Complete your account" and "Your invitation is waiting - click below to create your account. You'll be signed in immediately."

### Flow 4 — Duplicate access request submission

**Screenshot:** `/tmp/phase16-ux/20-duplicate-inline-error.png`, `/tmp/phase16-ux/35-mobile-error.png`

**Flow observed:**
1. Visit `/request-access`.
2. Type `dup-test-ux@example.com` (seeded pending request).
3. Submit.
4. Server returns `422` rendering the form again with an error block.

**Findings:**

- VERIFIED OK: Form re-renders with the email pre-filled.
- VERIFIED OK: Error appears visually prominent in a rose-tinted box at top of the form.
- VERIFIED OK: Mobile layout handles the error block gracefully.
- HIGH - Error message is ambiguous: "Email already has a pending request or approved invitation" forces the user to guess which state they're in. They can't distinguish:
  - "I already requested - admin is reviewing" (pending) -> user should wait
  - "My invitation was sent - check email" (approved) -> user should look for the email

  Recommended fix: Differentiate the two validations. `email_not_already_active` should branch:
  ```ruby
  if self.class.exists?(email: email, status: :pending)
    errors.add(:email, "is already pending review - we'll email you once an admin approves it")
  elsif self.class.exists?(email: email, status: :approved)
    errors.add(:email, "is already approved - check your email for the invitation link, or contact support if you can't find it")
  end
  ```
- HIGH - No role/aria-live on the error container: Confirmed via DOM inspection: `.rounded-2xl.bg-[var(--ha-error-container)]` has no `role="alert"`, no `aria-live`, and the email input has no `aria-invalid="true"` / `aria-describedby`. Screen readers will not auto-announce the error. See Accessibility section.

### Flow 5 — Already-registered email

**Screenshot:** `/tmp/phase16-ux/21-registered-email-error.png`

**Flow observed:**
1. Visit `/request-access`.
2. Type `joel@acme.org` (existing user).
3. Submit.
4. Server returns `422` with error "Email is already registered — please sign in".

**Findings:**

- VERIFIED OK: Error message is actionable and points toward the right action.
- HIGH - "Please sign in" is not a link: The error text mentions signing in but contains no direct link to `/login`. The user must locate the "Sign in" entry in the sidebar (left) while their attention is focused on the error (right-centre). Recommended fix: render the error with an inline link, e.g. `"is already registered — <a href='/login'>sign in here</a>"`. Phlex allows safe HTML via explicit escaping / raw blocks; or use a dedicated error renderer that injects the link structurally.
- MEDIUM - Even with the error, the CTA remains "Request Access": The form's primary button still says "Request Access", but submitting again will fail the same way. Consider disabling the button or swapping it to "Sign in instead" when this specific error is present.

### Flow 6 — Invited signup (happy path)

**Screenshots:** `/tmp/phase16-ux/22-invited-signup-form.png`, `/tmp/phase16-ux/23-after-invited-signup.png`, `/tmp/phase16-ux/24-welcome-flash.png`, `/tmp/phase16-ux/39-final-welcome-flash.png`, `/tmp/phase16-ux/25-mailcatcher.png`, `/tmp/phase16-ux/36-mobile-invited-signup.png`, `/tmp/phase16-ux/37-mobile-invited-signup.png`

**Flow observed:**
1. Visit `/create-account?invitation_token=tosiiogyUhQ5MK158aozEFcWkj4t8GUbAauXSc5SlXM`.
2. Form shows: email pre-filled (readonly), hidden `invitation_token`, "Create Account" submit button.
3. Helpful text: "This email is linked to your invitation and cannot be changed."
4. Submit.
5. User is redirected to `/`, auto-logged-in, sidebar shows authenticated nav, toast appears: "All set / Welcome! Your account is ready."
6. MailCatcher: only the admin-notification email was sent (`New user signed up: [FILTERED]`). No second "Verify account" email.

**Findings:**

- VERIFIED OK: Auto-login works; user does not have to sign in again after signup.
- VERIFIED OK: No duplicate verify-account email sent - confirms Phase 16's `create_verify_account_key` / `send_verify_account_email` / `verify_account_view` overrides work.
- VERIFIED OK: Flash toast text "Welcome! Your account is ready." confirms the override of `create_account_notice_flash`.
- VERIFIED OK: Email field is `readonly` and pre-filled from the invitation record.
- VERIFIED OK: Invitation token is carried in a hidden field so the Rodauth POST keeps the token even though the URL query string is dropped.
- CRITICAL - Heading says "Welcome BACK" for a first-time user: After invited signup, home shows `"Welcome back, <first-name>"`. This user has never been here before - the word "back" is incorrect and feels impersonal. Recommended fix: in `app/views/welcome/home.rb#render_hero_welcome`, check `current_user.sign_count` or introduce a `created_at < 1.minute.ago` check to switch between "Welcome" (first-time) and "Welcome back" (returning). Simplest option: just use "Welcome, first_name" universally.
- HIGH - Toast visually overlaps the Welcome heading on desktop: At 1280 px, the toast top-edge is at y~24 and the headline "Welcome back, final-ux-test" extends to ~x=1020 with 4xl font. The toast (x-start ~872, y~24) sits directly on top of the headline. Users see a crowded, visually noisy landing. Recommended fix: move toast container down (e.g. `top-20` instead of `top-6`) OR use a layout-aware positioning that pushes below the PageHeader region.
- HIGH - "Create account" page heading and subcopy are wrong for invited flow: The form on `/create-account?invitation_token=...` shows "Create account" / "Sign up with your email and we will verify it before you log in." - verification does NOT happen for invited users. Copy should be: "Complete your account" / "Click below to activate your account - you'll be signed in immediately."
- MEDIUM - Email field overflow on mobile: At 393 px width, a long email like `logged-out-login-test@example.com` (33 chars, ~314 px rendered) exceeds the 277 px input width; the right side (".com") is clipped on initial render. Users can scroll right to see it but might not realise. Recommended fix: either reduce the font-size on the pre-filled readonly field, or convert the readonly input to a non-input element (e.g. `<p class="ha-input">` or `text-lg` pill) that wraps or truncates with `...`.

### Flow 7 — Reused invitation token

**Screenshots:** `/tmp/phase16-ux/42-reused-invitation.png`, `/tmp/phase16-ux/43-reused-submit.png`

**Flow observed (follow-up edge case):**
1. Visit `/create-account?invitation_token=<already_accepted>`.
2. Form renders normally with NO pre-fill, NO readonly, NO "locked" message - looks like a fresh create-account form.
3. User types the same email, submits.
4. Redirect to `/` with generic "Invitation required" flash.

**Findings:**

- HIGH - Accepted tokens render a misleading form: The GET handler does not distinguish "accepted" vs "never existed" vs "expired" tokens. All three produce the same generic create-account form. A user re-clicking their invitation email to verify it worked would see a confusing empty form.

  Recommended fix: extend `validate_invitation_token` (or a new before-action on GET) to return more specific redirects:
  - Token not found -> `"Invitation required..."` + `/`
  - Token expired -> `"This invitation has expired - request a new one below."` + `/request-access`
  - Token already accepted -> `"This invitation has already been used. Please sign in."` + `/login`

---

## Accessibility Audit

Tested via DOM inspection and keyboard navigation on `/request-access` (most interactive of the new surfaces).

### Findings

- HIGH - Flash toasts have NO `role`, `aria-live`, or `aria-label`. Screen readers will NOT announce flash messages. Confirmed via:
  ```js
  document.querySelector('[data-controller=toast]').getAttribute('role') // null
  document.querySelector('[data-controller=toast]').getAttribute('aria-live') // null
  ```
  Recommended fix: in `app/components/flash_toasts.rb`, add `role: "alert", aria_live: "assertive"` to alert toasts and `role: "status", aria_live: "polite"` to notice toasts. File: `/home/joel/Workspace/Workanywhere/catalyst/app/components/flash_toasts.rb` lines 24-57.
- HIGH - Inline form errors lack `role="alert"` and field-level `aria-invalid`. Confirmed via DOM:
  ```js
  document.querySelector('.rounded-2xl.bg-\\[var\\(--ha-error-container\\)\\]').getAttribute('role') // null
  document.querySelector('input[type=email]').getAttribute('aria-invalid') // null
  document.querySelector('input[type=email]').getAttribute('aria-describedby') // null
  ```
  Recommended fix: in `/home/joel/Workspace/Workanywhere/catalyst/app/components/access_request_form.rb` lines 30-43, add `role: "alert", id: "access-request-errors"` to the error container, and when errors are present, set `aria-invalid: "true", aria-describedby: "access-request-errors"` on the email input.
- MEDIUM - Toast dismiss button has `aria-label="Dismiss notification"`, but the toast container itself has no label, so a user navigating the accessibility tree gets a generic div.
- MEDIUM - Tab order is fine, but the PWA install prompt steals the first two Tab stops (Install, Dismiss), pushing the actual onboarding form elements to Tab 3+. Consider wrapping the PWA banner in a landmark (already has one via its `pwa` controller, but the heavy tab cost is relevant).
- VERIFIED OK: Form labels are correctly associated via `for`/`id` (label "Email" -> `#access_request_email`).
- VERIFIED OK: Submit can be triggered with Enter key on the email input.
- VERIFIED OK: Dark mode text contrast appears WCAG AA compliant in spot checks (light grey on dark blue, white on red error button).
- VERIFIED OK: Buttons and links are distinguishable by shape/background, not only by colour.

---

## Mobile Audit (393 x 852)

### Findings

- HIGH - Mobile top-bar interactive elements are below the 44x44 px iOS touch-target minimum:
  - "Catalyst" home link: 68x28 (height too small)
  - Theme toggle button: 36x36
  - "Sign in" text link: 46x20 (height too small)

  These elements rely on a 16 px mobile header height. Users with motor impairments or thumb-typing will miss-tap. Recommended fix: in `app/components/mobile_top_bar.rb`, increase the header vertical padding (`h-16` -> `h-20`) and add `min-h-[44px] min-w-[44px]` to the toggle, logo, and sign-in link.
- MEDIUM - Readonly email field on invited signup overflows on narrow viewports. See Flow 6 finding above.
- MEDIUM - "Profile" label on bottom-nav for logged-out users is misleading. See Flow 1 finding above.
- VERIFIED OK: Card layout stacks vertically; no horizontal scrollbar.
- VERIFIED OK: Submit buttons (Request Access, Create Account) are 45 px tall on mobile - meets 44 px minimum.
- VERIFIED OK: Mobile dark mode renders correctly.
- VERIFIED OK: Error states render cleanly and don't break the layout on mobile.

---

## Dark Mode Audit

**Screenshots:** `/tmp/phase16-ux/30-mobile-dark-home.png`, `/tmp/phase16-ux/32-desktop-dark-home.png`, `/tmp/phase16-ux/29-mobile-dark-request-access.png`, `/tmp/phase16-ux/33-dark-home-after-wait.png`

- VERIFIED OK: Home page dark mode: backgrounds transition smoothly, text contrast readable, access card uses dark surface.
- VERIFIED OK: Request Access form dark mode: input field visible, submit button retains blue gradient.
- VERIFIED OK: Flash toasts work in dark mode (alert: rose gradient on dark; notice: emerald gradient on dark).
- MEDIUM - Sidebar transition jitter during initial render in dark mode: Screenshot 32 shows the sidebar briefly rendering in a light-neutral colour before theme CSS fully applies. This is a flash-of-unstyled-content (FOUC) for the sidebar specifically. Likely because the sidebar uses `bg-white/80 dark:bg-[var(--ha-surface)]/80` and the dark class is applied after initial paint. Not blocking but worth noting - a `<meta name="color-scheme" content="dark light">` in the layout or early inline script detection would smooth this.

---

## Broken / Dead-End Navigation Audit

- HIGH - Sidebar "Create account" link: As described in Flow 1, for logged-out users without an invitation this always dead-ends with a flash redirect. Remove or re-purpose the link.
- HIGH - Login page "More options -> Create a New Account" link: (`/tmp/phase16-ux/02-login-page.png`) On the `/login` page, under "More options", there's a link "Create a New Account" -> `/create-account`. Same dead-end as above. Remove or hide for anonymous users without an invitation.
- MEDIUM - Login page "Resend Verify Account Information" link: Since Phase 16 now skips `verify_account` for invited users (the only path to account creation), users who would click "Resend" have no account to verify. For non-invited users, the account doesn't exist to verify. This link is now orphaned. Hide or remove.
- VERIFIED OK: "Back to home" link on `/request-access` navigates correctly to `/`.
- VERIFIED OK: After invited signup, the sidebar transitions cleanly to the logged-in state (Trips, Notifications, My account, Add passkey, Sign out).

---

## PWA / Service Worker Notes

- VERIFIED OK: Service worker correctly skips non-GET requests (POST /login, POST /request-access, POST /create-account all work).
- VERIFIED OK: The SW cache is not interfering with session cookies on redirects.
- Observation: During testing, I needed to unregister the SW once because a long-lived session cookie appeared stuck. This was a test-artefact, not a real user issue, but worth a regression check if onboarding tests start flaking.

---

## Server-Side 500 Error Observed

While reviewing recent app logs for Phase 16 context, a separate 500 Internal Server Error was found from an earlier test run (not my test) when a user submitted an email containing a literal newline character (`test\nnull@example.com`). The DB query produced `SQLite3::SQLException: unrecognized token: 'test'`. This suggests the `email_not_already_active` exists? guard uses a parameter form that doesn't properly handle multi-line strings in certain code paths. Not part of Phase 16 but should be triaged as a separate bug.

File: `/home/joel/Workspace/Workanywhere/catalyst/app/models/access_request.rb:23` `exists?(email: email, status: %i[pending approved])` - investigate whether the `normalize_email` `.strip` is sufficient for all whitespace variants.

---

## Consolidated Defect List (Critical issues only)

- [ ] **[CRITICAL] `/create-account` GET without token renders a honeypot form.** Users waste effort typing their email only to be redirected. Either redirect the GET immediately to `/` with the flash, or render a blocking message. See Flow 3 above. Files: `app/misc/rodauth_main.rb` (consider adding `before_create_account_route` redirect), or add a Rails controller-level filter.
- [ ] **[CRITICAL] Invited signup home page says "Welcome back, <name>" for a first-time user.** Wrong word - the user has never been here. Change to "Welcome, <name>" or conditional "back" based on `sign_count`. File: `app/views/welcome/home.rb:31`.

### High (should-fix before merge)

- [ ] Sidebar "Create account" link is a trap for logged-out users - remove, re-label, or link to `/request-access`. File: `app/components/sidebar.rb`.
- [ ] Login page "Create a New Account" under More Options has the same trap. File: Rodauth login partial / overrides.
- [ ] Toast-based flash auto-dismisses too fast for actionable errors. Bump timeout to ~7 s for alert toasts or convert the login-bounce flash to a persistent inline banner. File: `app/javascript/controllers/toast_controller.js` (value), `app/components/flash_toasts.rb` (timeout value).
- [ ] Toast visually overlaps the main page headline on desktop after invited signup. Move the toast container down or make the PageHeader reserve top space. File: `app/components/flash_toasts.rb:10` (adjust `top-6` -> `top-20`) or restructure.
- [ ] "Create account" page heading/subcopy are wrong for invited flow - no verification happens. File: Rodauth `create-account` Phlex view (check `app/components/rodauth_*.rb`).
- [ ] Duplicate access-request error does not distinguish pending vs approved. Split the validation in `app/models/access_request.rb:22-27` into two cases with appropriate copy.
- [ ] "Please sign in" error has no inline link - add a link to `/login` inside the error message. File: `app/models/access_request.rb:33` (error message text) + `app/components/access_request_form.rb`.
- [ ] Accepted/expired invitation tokens render a misleading form. Distinguish in `validate_invitation_token` and redirect with specific copy. File: `app/misc/rodauth_main.rb:105-113`.
- [ ] Flash toasts have no `role="alert"` / `aria-live`. File: `app/components/flash_toasts.rb:24-57`. Screen-reader users miss all transient feedback.
- [ ] Inline form errors have no `role="alert"` / `aria-invalid` / `aria-describedby`. File: `app/components/access_request_form.rb:30-43`.
- [ ] Mobile top-bar touch targets are under 44x44 px (theme toggle, Catalyst logo, Sign in). File: `app/components/mobile_top_bar.rb`.
- [ ] Headline left-aligned while access card is centred - pick one alignment. File: `app/views/welcome/home.rb:179-194`.

### Medium

- [ ] Mobile bottom-nav "Profile" label should be "Sign in" when logged out. File: `app/components/mobile_bottom_nav.rb:26`.
- [ ] Readonly email field on invited signup overflows at 393 px. File: Rodauth `create-account` view.
- [ ] `/login` "Resend Verify Account Information" link is orphaned (no flow reaches it). Hide it.
- [ ] No persistent visual reinforcement on `/` after a failed login - only the 4.5 s toast. Consider a banner.
- [ ] Error messages don't offer to switch the user's intent (e.g. "Sign in instead" button when email is already registered).

### Low

- [ ] Sidebar brief FOUC on dark-mode initial paint (light-neutral before dark CSS kicks in).
- [ ] PWA install prompt consumes the first two Tab stops on every logged-out page - minor friction for keyboard users.

### Verified OK

- Redirect from `/login` POST with unknown email -> `/` works.
- Redirect from `/create-account` POST with no token -> `/` works.
- Flash copy "Invitation required. Request access below." appears consistently.
- Successful access request shows green success toast "Your access request has been submitted. We'll be in touch!"
- Duplicate email shows inline 422 error with pre-filled field.
- Already-registered email shows inline 422 error with pre-filled field.
- Invited signup auto-logs-in the user.
- Invited signup suppresses the verify-account email (only admin-notification email sent).
- "Welcome! Your account is ready." toast appears after invited signup.
- Sidebar transitions to authenticated state after successful signup.
- Dark mode renders correctly on all new/changed surfaces.
- Desktop layout holds at 1280 px.
- Mobile layout holds at 393 px (with noted touch-target caveats).
- Keyboard submit (Enter) works on the access-request form.
- Form labels are correctly associated with inputs.
- "Back to home" escape hatch on `/request-access` navigates correctly.

---

## Screenshots Index

All screenshots in `/tmp/phase16-ux/`:

| File | Description |
|---|---|
| `01-home-logged-out-light.png` | Logged-out home (light, desktop) |
| `02-login-page.png` | Login page with More Options |
| `03-login-unknown-email-redirect.png` | After unknown-email login (toast dismissed) |
| `14-immediate-screenshot.png` | Toast visible after unknown-email login |
| `15-create-account-no-token.png` | GET /create-account renders unrestricted form |
| `16-create-account-no-token-submitted.png` | Flash after /create-account POST (fading) |
| `18-request-access.png` | Request Access form (desktop) |
| `20-duplicate-inline-error.png` | Duplicate request error (desktop) |
| `21-registered-email-error.png` | Registered email error |
| `22-invited-signup-form.png` | Invited signup form with pre-filled email |
| `23-after-invited-signup.png` | Auto-logged-in home after signup (toast dismissed) |
| `24-welcome-flash.png` | "Welcome! Your account is ready." toast visible |
| `25-mailcatcher.png` | MailCatcher confirms no verify-account email |
| `26-mobile-home.png` | Mobile home (light) |
| `28-mobile-request-access.png` | Mobile Request Access (light) |
| `29-mobile-dark-request-access.png` | Mobile Request Access (dark) |
| `30-mobile-dark-home.png` | Mobile home (dark) |
| `32-desktop-dark-home.png` | Desktop home (dark) |
| `33-dark-home-after-wait.png` | Desktop dark home with alert toast visible |
| `34-logged-out-home-fresh.png` | Fresh logged-out home (ha-rise mid-animation) |
| `35-mobile-error.png` | Mobile registered-email error |
| `37-mobile-invited-signup.png` | Mobile invited signup, email truncated |
| `37b-email-scrolled.png` | Mobile email field scrolled right manually |
| `39-final-welcome-flash.png` | Welcome toast overlapping headline after invited signup |
| `40-success-submitted.png` | Access request success toast |
| `41-login-with-passkey-prompt.png` | Login next step: passkey vs email link |
| `42-reused-invitation.png` | Already-accepted token renders normal form |
| `43-reused-submit.png` | Flash after reused-token submit |

---

## Reviewer notes

- The Phase 16 changes successfully remove the previous two-panel confusion and enforce the invite-only policy on `/login` and `/create-account` POST.
- The main remaining UX weakness is on the **GET `/create-account`** path and in the **copy used across invited signup** (Create Account / Welcome back).
- Accessibility has regressed relative to WCAG AA expectations because the new toast-based redirects aren't announced by screen readers.
- The flow-coherence concern flagged in the brief ("does the flash and CTA connect?") is valid and addressable: the flash is well-worded but too transient, and the CTA's visual position and animation timing don't support the flash's directive.

---

## Skill Self-Evaluation

**Skill used:** ux-review

**Step audit:**
- All steps from the SKILL.md were executed (screenshot each changed surface, check flow/clarity, forms, navigation, authorization-aware UI, accessibility, responsive, dark mode).
- One deviation: I spent several extra iterations debugging a timing artefact where `agent-browser` screenshots were taken after the 4.5 s toast had auto-dismissed. This was not a bug in the app - the toast was correctly rendered each time - but took multiple attempts to prove. The SKILL.md does not mention the risk that auto-dismissing toasts will be invisible in post-navigation screenshots.
- The skill's PWA/service-worker section was triggered only briefly. Service worker interference was ruled out quickly because curl and browser flows produced the same HTML.

**Improvement suggestion:** Add a "transient UI timing" note to the skill: "When flash toasts are auto-dismissed (Stimulus `toast_controller` with a timeout), screenshot within 1 s of the redirect, or temporarily override `toast_timeout_value` to 0 / disable dismissal in the review session. Do not rely on `sleep` + screenshot."
