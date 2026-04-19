# QA Review -- feature/phase16-onboarding-improvements

**Branch:** `feature/phase16-onboarding-improvements`
**Phase:** 16 (Onboarding Improvements)
**PR:** #103 -- https://github.com/joel/trip/pull/103
**Date:** 2026-04-18
**Reviewer:** Claude (adversarial QA pass)
**Test target:** `https://catalyst.workeverywhere.docker/` (container `catalyst-app-dev`)

---

## Executive Summary

| Severity | Count | Items |
|----------|-------|-------|
| 🔴 Critical / Broken / Defect | 2 | Null byte in email → HTTP 500; HTTP 302 redirect from POST breaks non-browser clients |
| 🟠 High | 2 | Mixed-case email creates unrecoverable lockout; Misleading copy on /create-account ("we will verify it before you log in") |
| 🟡 Medium | 2 | No email length validation (RFC 5321 violations accepted); "Sign in" in sidebar can still lead users to the dead-end flash-redirect loop |
| 🟢 Low | 3 | PWA "Install" button below 44×44 touch target; Flash toast overlaps mobile header; Rate limiting absent on `/request-access` (pre-existing) |
| ✅ Verified OK | 18 | See verified list below |

---

## Test Suite Results

- **Non-system specs (`rake project:tests`):** 585 examples, 0 failures, 2 pending
- **System specs (`TEST_BROWSER=selenium_chrome_headless rake project:system-tests`):** 63 examples, 0 failures
- **System specs (`rake project:system-tests` without TEST_BROWSER override):** 63 examples, **51 failures** — environment/display issue (visible Chrome driver with `ha-fade-in` / `ha-rise` CSS animations; Capybara sees opacity:0 as non-visible). **Pre-existing issue on `main` too**. Not Phase-16-introduced.
- **Phase 16 added specs:** `spec/system/onboarding_redirects_spec.rb`, `spec/system/invitations_spec.rb`, `spec/system/welcome_spec.rb`, `spec/models/access_request_spec.rb`, `spec/actions/access_requests/submit_spec.rb`, `spec/requests/access_requests_spec.rb` — all pass in headless mode.
- **Linting:** RuboCop 424 files, 0 offenses. ERBLint 17 files, 0 errors.

---

## Acceptance Criteria (Phase 16 plan §3)

- [x] **Home (logged-out) shows only "Request an invitation" card** — PASS (verified in browser `https://catalyst.workeverywhere.docker/`; returning-user "Sign in" card is gone; text "Returning?" not present in HTML).
- [x] **Unknown-email login redirects to `/` with "Invitation required" flash** — PASS (verified via browser; `before_login_route` hook runs; flash toast visible).
- [x] **Create-account without token redirects to `/` with same flash** — PASS (verified both via curl and via browser; `validate_invitation_token` now redirects to `/` not `/create-account`).
- [x] **Duplicate access requests blocked (pending/approved/existing user)** — PASS (model validations + partial unique index verified).
- [x] **Rejected access requests may resubmit** — PASS (verified with seeded `rejected-user@example.com`).
- [x] **Invited accounts skip verify-account + auto-login** — PASS (user created with `status=2`, no verify email sent, session authenticated, redirect to `/`).
- [x] **"Welcome! Your account is ready." flash on invited signup** — PASS (flash in session cookie; shown on redirect-target page).
- [x] **Email case-insensitive deduplication on AccessRequest** — PASS (`normalize_email` before_validation; duplicate `CASE@Example.COM` blocked when `case@example.com` exists).
- [x] **Partial unique DB index (`status IN (0, 1)`) + dedupe migration** — PASS (`idx_access_requests_active_email_uniqueness` present; direct SQL insert bypassing AR blocks at DB level).
- [x] **`ActiveRecord::RecordNotUnique` race rescue** — PASS (5 parallel POSTs produced 1 row, others returned 422 with friendly message).

---

## 🔴 Critical Defects (MUST fix before merge)

### D1 🔴 — Null byte in email triggers HTTP 500 on `/request-access`

**Severity:** 🔴 Critical / Defect (Phase-16-introduced)
**File:** `app/models/access_request.rb:22-27`
**Evidence:** Server log stack trace `SQLite3::SQLException: unrecognized token: "'test"` at `AccessRequest#email_not_already_active`.

**Steps to reproduce:**
1. `curl -sk -c /tmp/c.txt https://catalyst.workeverywhere.docker/request-access -o /tmp/req.html`
2. Extract `authenticity_token` from form.
3. POST with body containing a raw null byte in the email:
   ```bash
   python3 -c "
   import urllib.parse, sys
   data = urllib.parse.urlencode({'authenticity_token': '<TOKEN>', 'access_request[email]': 'test\x00null@example.com'})
   sys.stdout.buffer.write(data.encode())" > /tmp/body.txt

   curl -sk -b /tmp/c.txt -X POST https://catalyst.workeverywhere.docker/request-access \
     -H "Content-Type: application/x-www-form-urlencoded" \
     --data-binary @/tmp/body.txt -w "%{http_code}"
   ```

**Expected:** 422 unprocessable_content with `email is invalid`.
**Actual:** HTTP 500 Internal Server Error.

**Root cause:** The new `email_not_already_active` and `email_not_already_registered` validations run **before** the format validator's failure has a chance to short-circuit the query. `AccessRequest.exists?(email: email, status: ...)` interpolates the null-terminated string into the SQLite bind, SQLite treats `\x00` as end-of-string, and the prepared SQL becomes truncated / malformed. The Submit action's rescue only catches `RecordInvalid` and `RecordNotUnique`, so `StatementInvalid` propagates up and returns a 500.

**Recommended fix:** Guard the new validations against invalid-format input:
```ruby
def email_not_already_active
  return if email.blank?
  return unless email.match?(URI::MailTo::EMAIL_REGEXP)
  return unless self.class.exists?(email: email, status: %i[pending approved])
  errors.add(:email, "already has a pending request or approved invitation")
end
```
(Apply same guard to `email_not_already_registered`.) Alternatively, add a `StatementInvalid` rescue in `AccessRequests::Submit#persist` that returns `Failure(errors)` with a generic "invalid email" error.

**Regression spec:** Add a request spec that POSTs `test\x00null@example.com` and asserts HTTP 422, not 500.

---

### D2 🔴 — POST /login and POST /create-account return HTTP 302 → non-browser clients re-POST to `/` → 404

**Severity:** 🔴 Critical / Defect (Phase-16-introduced)
**File:** `app/misc/rodauth_main.rb:76-85` (`before_login_route` hook) and `app/misc/rodauth_main.rb:105-113` (`validate_invitation_token`)
**Evidence:** Verified via curl with `-L`:

```
POST /login   → HTTP 302, location: /
GET/POST /    → HTTP 404 (because strict RFC 7231 clients preserve POST method on 302 responses)
```

**Steps to reproduce:**
```bash
rm -f /tmp/c.txt
curl -sk -c /tmp/c.txt https://catalyst.workeverywhere.docker/login -o /tmp/l.html
TOKEN=$(grep -oE 'name="authenticity_token"[^>]*value="[^"]*"' /tmp/l.html | head -1 | sed 's/.*value="//;s/".*//')
curl -sk -b /tmp/c.txt -c /tmp/c.txt -X POST https://catalyst.workeverywhere.docker/login \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "email=unknown-ghost@example.com" \
  -L -w "HTTP: %{http_code}\n" -o /dev/null
# HTTP: 404
```

**Expected:** Redirect that all clients (browsers, `curl -L`, mobile apps, scripted tests) follow as GET to `/`.
**Actual:** Only browsers convert POST→GET on 302. Strict RFC-compliant clients and `curl -L` preserve the POST method on 302, triggering `ActionController::RoutingError (No route matches [POST] "/")` and a 404.

**Real-world impact:**
- Anyone scripting the login flow (QA harnesses, monitoring, automation) will hit a 404 instead of being redirected to the home page.
- Webhook-style "bad-credentials" handlers in third-party tools may behave oddly.
- Mobile WebView clients without special-case logic may also re-POST.

**Recommended fix:** Use HTTP 303 See Other (which all clients must follow as GET) for redirects from POST endpoints. Rodauth's `redirect` delegates to Roda's `request.redirect(path, status=302)`. Override in the two hooks:
```ruby
before_login_route do
  # ...
  set_redirect_error_flash "Invitation required. Request access below."
  request.redirect "/", 303
end

def validate_invitation_token
  # ...
  set_redirect_error_flash "Invitation required. Request access below."
  request.redirect "/", 303
end
```

---

## 🟠 High-Severity Defects

### D3 🟠 — Mixed-case invited email + case-sensitive Rodauth lookup + Phase 16 unknown-email redirect = unrecoverable lockout

**Severity:** 🟠 High (pre-existing Rodauth case-sensitivity, worsened in UX by Phase 16)
**Files:** `app/misc/rodauth_main.rb:108-113` (`validate_invitation_token` uses case-insensitive comparison), `app/views/rodauth/create_account.rb:53-87` (email is only `readonly` client-side), `app/models/user.rb:28` (case-insensitive validation but no normalization).

**Steps to reproduce:**
1. Admin creates an invitation with mixed-case email: `Mixed-Case@Example.COM` (the `Invitation` model accepts it as-is — see D9 in the security review).
2. Invitee loads `/create-account?invitation_token=<token>` — form is pre-filled and `readonly` (client-side only).
3. Invitee opens devtools and removes `readonly`, submits with lowercased `mixed-case@example.com`. **Or** invitee submits the pre-filled mixed-case email directly (as the form shows it).
4. Either way, the User is created with whatever case the POST body contained.
5. User later tries to log in with lowercase `mixed-case@example.com` → Rodauth's `_account_from_login` does a case-sensitive `email = 'mixed-case@example.com'` match, returns nil → Phase 16's `before_login_route` short-circuits to `/` with flash **"Invitation required. Request access below."**

**Expected:** A legitimate user whose account exists (modulo case) can log in. Or at minimum, receive an error like "Check your email for the correct casing" — not "Invitation required. Request access below." (implying they have no account at all).

**Actual:** The user sees the invitation-required flash, clicks "Request Access", gets blocked because their email is already registered (case-insensitive, via `email_not_already_registered`). They are locked out and the system gives no clear indication why.

**Recommended fix:** Two changes needed:
1. Normalize email on `User` model (add `before_validation { self.email = email.to_s.downcase.strip.presence }` — same pattern as `AccessRequest`).
2. Normalize email on `Invitation` creation (so admins can't create mixed-case invitations). This is called out in the security review's Low #1.

Both changes should be applied in **a fast-follow PR** — they are small, well-scoped, and test-covered by the existing case-insensitivity specs in `access_request_spec.rb` (just move the patterns to User and Invitation).

**Regression spec needed:** Add a system spec: "Invitee can log in with lowercase email even if admin invited with mixed case".

---

### D4 🟠 — /create-account subtitle text is misleading for invited signups

**Severity:** 🟠 High (UX defect introduced indirectly by Phase 16)
**File:** `app/views/rodauth/create_account.rb:17`

**Current copy:** *"Sign up with your email and we will verify it before you log in."*

**Problem:** Phase 16 explicitly skips verification for invited users (the whole point of task 5 in the plan). The user just gave their email once — they are NOT going to receive a verify-account email, and they WILL be auto-logged-in. The subtitle tells them the opposite.

**Steps to reproduce:**
1. Create an invitation for `visual-test@example.com`.
2. Load `https://catalyst.workeverywhere.docker/create-account?invitation_token=<token>`.
3. Observe the subtitle under the heading says "we will verify it before you log in."
4. Submit the form — no verify email is sent, user is logged in immediately. The subtitle was a lie.

**Expected:** For invited users, the subtitle should reflect the actual behavior. E.g., "Your invitation is ready — click below to finish creating your account." The template needs a branch for `invitation_token.present?`.

**Recommended fix:** In `app/views/rodauth/create_account.rb`, conditionally render the subtitle:
```ruby
p(class: "mt-2 text-sm text-[var(--ha-on-surface-variant)]") do
  if view_context.params[:invitation_token].present?
    plain "You've been invited. Click below to finish creating your account."
  else
    plain "Sign up with your email and we will verify it before you log in."
  end
end
```

---

## 🟡 Medium-Severity Findings

### E1 🟡 — No email length validation on `AccessRequest`

**Severity:** 🟡 Medium (pre-existing but Phase 16 is the right moment to fix it since this phase touches the model)
**Evidence:** Submitting a 262-character email is accepted and stored:
```bash
# Email with 262 chars (250 "a"s + "@example.com") returns HTTP 302 (success)
```

**Risk:**
- Violates RFC 5321 (max 254 chars). Downstream email delivery could fail silently.
- Opens a minor DoS vector (arbitrary-length strings in `email` column).
- Hurts data quality and may break downstream UI that expects reasonable lengths.

**Recommended fix:** Add `length: { maximum: 254 }` to the email validation on `AccessRequest` (and match it on `User` and `Invitation` while you're there).

---

### E2 🟡 — Sidebar "Sign in" + "Create account" links still lead to the flash-redirect loop for truly-unknown users

**Severity:** 🟡 Medium (not a defect per Phase 16 plan — plan explicitly keeps these links — but the user journey is leakier than advertised)
**File:** `app/components/sidebar.rb` (and mobile nav in `app/views/layouts/application_layout.rb`)

**Observation:** The plan states "The sidebar 'Sign in' / 'Create account' nav items for logged-out visitors stay in place (users still have a way to sign in without the homepage panel)." But the user who doesn't have an account will still click "Sign in", submit an email, get redirected home with the flash. The flash helps — but the same user can then click "Create account" in the sidebar, submit an email (no token), and get redirected again.

**Risk:** Mild user confusion and a slightly noisier access-request pipeline. A user who keeps clicking "Sign in" / "Create account" burns cycles before eventually noticing "Request Access" in the centre card.

**Recommendation:** Consider a second-phase tweak — either hide "Create account" from the sidebar when no invitation token is present, or change "Sign in" to "Log in" and make "Create account" show a modal "Need an invitation? Request access here." OR accept this as a Phase 17 ticket.

---

## 🟢 Low-Severity / Polish

### E3 🟢 — PWA "Install" button fails 44×44 touch target on mobile (73×40)

**Severity:** 🟢 Low (pre-existing, visible on every page at mobile width)
**Evidence:**
```js
Array.from(document.querySelectorAll('button, a')).filter(el => {
  const r = el.getBoundingClientRect();
  return r.width > 0 && (r.width < 44 || r.height < 44);
}).map(el => el.textContent.trim().slice(0,30) + ' ' + Math.round(el.getBoundingClientRect().height) + 'px');
// → ["Install 40px"]
```

**Recommendation:** Bump padding to reach 44×44.

---

### E4 🟢 — Flash toast overlays mobile header for first ~second

**Severity:** 🟢 Low (UX)
**File:** `app/components/flash_toasts.rb` or similar

**Observation:** On mobile (393×852), the "Action needed — Invitation required" toast appears at the top-right and overlaps the "Sign in" link in the header until it fades in.

**Recommendation:** Push the toast below the header on mobile widths (e.g. `top-20` for `sm:`-size breakpoints).

---

### E5 🟢 — No rate limiting on `POST /request-access`

**Severity:** 🟢 Low (pre-existing; not Phase 16 scope)
**Evidence:** 10 parallel POSTs with 10 different emails all succeed (HTTP 302).

**Risk:** Anyone can spam the access-request admin inbox. Also a minor DoS vector (unbounded writes to `access_requests` table). Not specific to Phase 16 but worth noting because Phase 16 is the moment the team is thinking about this flow.

**Recommendation:** Follow-up ticket to add `rack-attack` with a throttle on `/request-access` (e.g. 5 req/IP/hour).

---

## ✅ Verified OK

1. **MCP endpoint still works** — tools/list returns 12 tools; auth 401/415/−32700 behave as designed; create_journal_entry on started trip succeeds; create_journal_entry on finished trip returns "not writable"; unknown tool returns "Tool not found"; get_trip_status on Iceland (started) returns correct metadata.
2. **Happy-path invited signup** — User created with `status = 2` (verified), invitation marked `accepted`, `after_create_account` calls `Invitations::Accept`, no verify email in MailCatcher, redirect to `/`, session authenticated.
3. **Mismatched invitation token + different email** — redirects to `/` with flash; user not created; invitation stays pending.
4. **Expired invitation token** — blocked by `Invitation.valid_tokens`; redirects to `/`; user not created.
5. **Already-accepted invitation token** — blocked by `Invitation.valid_tokens`; no duplicate user.
6. **Garbage invitation_token** — blocked; redirects to `/`.
7. **SQL-injection-style invitation_token** — blocked; parameterized queries prevent injection; no user created.
8. **Null byte in invitation_token** — blocked; redirect to `/` (because `valid_tokens.find_by(token: ...)` returns nil).
9. **Case-insensitive access-request dedupe** — `Case@Example.COM` + `case@example.com` submissions result in one pending row with lowercased email.
10. **Rejected access requests may resubmit** — verified with seeded `rejected-user@example.com` — new pending row created.
11. **Concurrent duplicate access-request submissions** — 5 parallel POSTs produced 1 row, others got 422 with "already has a pending request or approved invitation".
12. **Unique partial index (`status IN (0, 1)`)** — direct SQL insert bypassing AR is rejected with SQLite `UNIQUE constraint failed`.
13. **`access_request.approved` → invitation pipeline** — verified with a test approval; `SendInvitationForApprovedRequestJob` runs; Invitation row created with `pending` status and 7-day expiry.
14. **CSRF protection on /request-access, /login, /create-account** — invalid CSRF token returns 422 (InvalidAuthenticityToken).
15. **URI::MailTo::EMAIL_REGEXP rejects XSS/SQLi patterns** — `<script>`, `' OR '1'='1`, Unicode-only local parts all return 422.
16. **Unverified legacy user (status=1) login** — still works via verify-account-resend flow (Phase 16 didn't touch this).
17. **Alice (existing user) login continues to work** — POST to /login with her email returns 200 with multi-phase login page (not a redirect).
18. **AccessRequest email normalization** — leading/trailing whitespace stripped, email downcased before validation.

---

## Regression Check

- **Trip CRUD** — Not re-verified (Phase 16 doesn't touch trips); no reports of regression.
- **Journal entries** — Not re-verified (out of scope); MCP `create_journal_entry` still works.
- **Authentication (existing verified user)** — ✅ PASS (alice login returns 200 multi-phase).
- **Authentication (legacy unverified user)** — ✅ PASS (john.doe@acme.org gets "resend verify" page).
- **Comments & reactions** — Not re-verified (Phase 16 doesn't touch them).
- **MCP Server** — ✅ PASS (full tool list and representative calls tested below).

---

## MCP Server Matrix

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| tools/list returns 12 tools | 12 | 12 | ✅ |
| Auth: no key | 401 | 401 | ✅ |
| Auth: wrong key | 401 | 401 | ✅ |
| Auth: wrong content-type | 415 | 415 | ✅ |
| Auth: malformed JSON | `{-32700, "Parse error"}` | matches | ✅ |
| get_trip_status (Iceland, started) | success + trip data | success | ✅ |
| create_journal_entry (Iceland, started) | success | created id `019da225-...` | ✅ |
| create_journal_entry (Japan, finished) | "not writable" | `"Trip 'Japan Spring Tour' is not writable (state: finished)"` isError=true | ✅ |
| Unknown tool name | error response | `-32602 "Invalid params" "Tool not found: nonexistent_tool"` | ✅ |

**Not re-tested (out of scope for onboarding change):** create_comment state guards, upload_journal_images validation variants, rate limiting on MCP. Covered by security-review and qa-review for their respective phases.

---

## Mobile (393×852)

| Page | Overflow | Buttons Work | Touch Targets OK | Notes |
|------|----------|-------------|------------------|-------|
| Home (logged out) | OK | ✅ | ⚠️ 4 elements < 44px | Install (73×40), Catalyst (68×28), dismiss (36×36), Sign in (46×20) |
| Login | OK | ✅ | ⚠️ Install (73×40) | Form usable; Login button meets target |
| Create account (w/ token) | OK | ✅ | ⚠️ Install (73×40) | Email field correctly disabled; submit button usable |
| Request access | OK | ✅ | ⚠️ Install (73×40) | Form + "Back to home" usable |
| Redirect-with-flash (/) | OK | ✅ | ⚠️ Install (73×40) | Flash toast briefly overlaps header (E4) |

---

## Test Environment Notes

- **System-test flakiness** (`selenium_chrome` driver) is **not** Phase-16-introduced. On `main`, `bundle exec rspec spec/system` also produces 51 animation-related failures when the visible Chrome driver is used on a display with GPU acceleration. Using `TEST_BROWSER=selenium_chrome_headless` yields 0 failures. The `spec/support/system_test.rb` default of `:selenium_chrome` should probably switch to `:selenium_chrome_headless` or explicitly set `prefers-reduced-motion: reduce` on the test browser to avoid this. **Out of Phase 16 scope** but worth a follow-up issue.

---

## Consolidated Defect List (🔴 Blockers for Merge)

- [ ] **D1** — `AccessRequest` email validations must guard against null-byte / invalid-format input before hitting the DB (`app/models/access_request.rb:22-34`). Without this fix, a trivial POST causes a 500. See D1 above for the recommended patch and a regression spec.
- [ ] **D2** — Switch `before_login_route` and `validate_invitation_token` redirects from HTTP 302 to 303 (or use `request.redirect "/", 303` explicitly). Without this fix, non-browser HTTP clients following the redirect re-POST to `/` and get a 404. See D2 above for the patch.

🟠 High-severity defects (D3, D4) are also strongly recommended before merge, but can be split into a fast-follow PR if the team explicitly accepts the risk.

---

## Recommended Next Steps

1. **Open fix for D1** — unit spec first (`spec/models/access_request_spec.rb` adding `it "rejects emails with null bytes" do ...`), then guard, then re-run.
2. **Open fix for D2** — system spec first (POST via `Net::HTTP` or `curl -L` and assert the final HTTP code is 200/GET, not 404/POST).
3. **Discuss D3 (mixed-case lockout)** — user-facing severity is high; if we accept fast-follow, file an issue labeled `fix` and `phase-16-followup` linking to this report.
4. **D4 (misleading subtitle)** — one-line copy tweak. No tests needed. Can ride in the D1/D2 PR.
5. After merge, update `prompts/Phase 16 - Steps.md` with the post-QA fix commits, same as round 1 review.
