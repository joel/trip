# QA Review -- feature/remember-persistent-sessions

**Branch:** `feature/remember-persistent-sessions`
**Phase:** X
**Date:** 2026-04-01
**Reviewer:** Claude (adversarial QA pass)
**Issue:** #64 -- Enable Rodauth :remember feature for persistent sessions

---

## Test Suite Results

- **Unit/request tests:** 555 examples, 0 failures, 2 pending
- **System tests:** 54 examples, 0 failures
- **Linting:** 414 files inspected, no offenses (RuboCop); 17 ERB files, no errors

---

## Acceptance Criteria

- [x] **Remember feature enabled** -- PASS: `RodauthApp.rodauth.features` includes `:remember`
- [x] **Remember key created on login** -- PASS: Login via email-auth creates a row in `user_remember_keys` with 30-day deadline
- [x] **Session extends with activity** -- PASS: `extend_remember_deadline?` is `true`, `load_memory` is called on every request
- [x] **Logout clears the remember cookie** -- PASS: Rodauth's `after_logout` hook calls `forget_login` which deletes the `_remember` cookie
- [x] **Token has configurable expiry** -- PASS: `remember_deadline_interval` set to `{ days: 30 }`
- [x] **No UI changes required** -- PASS: No new views, forms, or user-facing elements added
- [x] **Auto-remember on all login methods** -- PASS: `after_login { remember_login }` is called for email-auth, WebAuthn, and OmniAuth login pathways (verified by reading Rodauth source -- all call `after_login` via hook chain)
- [x] **Cookie security** -- PASS: Rodauth sets `httponly: true` and `secure: true` (when on SSL) by default; cookie is not accessible via `document.cookie`

---

## Defects (must fix before merge)

### D1: `remember_period` not set -- deadline extension uses 14 days instead of 30

**File:** `app/misc/rodauth_main.rb:24`
**Severity:** Medium

**Description:** The configuration sets `remember_deadline_interval({ days: 30 })` which controls the **initial** deadline when a remember key is created. However, `remember_period` (which controls the deadline used when **extending** via `load_memory` + `extend_remember_deadline`) is not set and defaults to `{ days: 14 }`.

This means:
1. User logs in -- remember key deadline is set to NOW + 30 days (correct)
2. User visits a page after the `extend_remember_deadline_period` (1 hour default) -- `extend_remember_deadline` resets the deadline to NOW + **14 days** (using `remember_period`)
3. From this point on, the effective remember window is 14 days, not 30

**Verified in Docker:**
```
remember_deadline_interval: {days: 30}
remember_period: {days: 14}   # <-- defaults to 14, not overridden
```

**Steps to reproduce:**
1. Log in via email-auth
2. Observe `deadline` in `user_remember_keys` is ~30 days from now
3. Wait >1 hour (or simulate by adjusting `extend_remember_deadline_period`)
4. Visit any page -- `load_memory` calls `extend_remember_deadline`
5. Observe `deadline` is now ~14 days from now (reduced from 30)

**Expected:** Extended deadline should remain 30 days
**Actual:** Extended deadline drops to 14 days

**Recommended fix:** Add `remember_period({ days: 30 })` to match `remember_deadline_interval`:

```ruby
# Remember me (persistent sessions)
remember_table :user_remember_keys
remember_deadline_interval({ days: 30 })
remember_period({ days: 30 })
extend_remember_deadline? true
```

---

## Edge Case Gaps (should fix or document)

### E1: Account verification auto-login does not set remember cookie

**Risk if left unfixed:** Low. Users who verify their account via the email link are auto-logged in via `autologin_session("verify_account")`, which calls `login_session` directly and bypasses `after_login`. This means the user's first session after account creation will NOT have a remember cookie. They will need to log out and log back in to get persistent sessions.

**Recommendation:** Acceptable for now. The user's next explicit login will set the remember cookie. If desired, add `remember_login` to `after_verify_account` or the custom `verify_account_view` method.

### E2: No `SameSite` attribute on remember cookie

**Risk if left unfixed:** Low. The `remember_cookie_options` defaults to an empty hash `{}`. The remember cookie does not explicitly set `SameSite`. Modern browsers default to `SameSite=Lax` which provides reasonable CSRF protection, but explicitly setting it is a defense-in-depth measure.

**Recommendation:** Consider adding `remember_cookie_options(same_site: :lax)` for explicit control. Not a blocker.

### E3: No system test coverage for remember feature

**Risk if left unfixed:** Medium. The test login helper (`TestSessionsController#show`) directly sets session keys without going through Rodauth's `after_login` hook, so `remember_login` is never called in system tests. The request specs verify configuration but not the actual end-to-end behavior (cookie creation, `load_memory` re-authentication, logout clearing).

**Recommendation:** Add at least one integration test that logs in via the email-auth flow and verifies a `user_remember_keys` record is created. This would catch regressions if the `after_login` hook is modified.

### E4: No cleanup of expired remember keys

**Risk if left unfixed:** Low. Expired remember keys accumulate in the `user_remember_keys` table. Rodauth does not automatically clean them up. With a small user base this is negligible, but at scale it could waste storage.

**Recommendation:** Add a periodic cleanup job or a rake task. Not a blocker for merge.

### E5: Database record persists after logout

**Risk if left unfixed:** None. By design, Rodauth's `forget_login` (called in `after_logout`) only clears the browser cookie. The database record remains but is harmless without the matching cookie token. The record will not match on `load_memory` because the cookie is gone.

---

## Observations

- **Code quality is high.** The implementation follows Rodauth's documented patterns exactly. The migration, feature enable, table naming, and route integration are all correct.
- **The `load_memory` placement is correct.** It is called in the `route` block before `r.rodauth`, which matches Rodauth documentation. Every request will check for the remember cookie and auto-login if valid.
- **The `after_login` hook order is correct.** `remember_login` is called before the OmniAuth name backfill logic, which is fine since `remember_login` operates on the session/cookie level and does not depend on account attributes.
- **The migration uses `id: false` with a UUID primary key** that is also the foreign key to `users`, following the project convention for Rodauth key tables (`user_email_auth_keys`, `user_verification_keys`).
- **The spec files use `rodauth_class.allocate`** to test configuration without a full request context. This is a pragmatic approach for testing configuration values, though it means the specs do not exercise the actual remember flow.

---

## Regression Check

- **Trip CRUD** -- PASS: Trips index renders with 5 seeded trips; Japan trip detail page renders with all elements
- **Journal entries** -- PASS: Entry with comments renders correctly at `/trips/.../journal_entries/...`
- **Authentication** -- PASS: Full email-auth login flow works (email sent, link received, login confirmed, session created, remember key created)
- **Comments & reactions** -- PASS: Seeded comments visible on journal entry page
- **Users page** -- PASS: Users index renders with admin navigation
- **Account page** -- PASS: Account page renders for logged-in user
- **MCP Server** -- PASS: See table below

---

## MCP Server

| Test | Expected | Actual |
|------|----------|--------|
| tools/list returns 12 tools | 12 | 12 -- PASS |
| Auth: no key | 401 | 401 -- PASS |
| Auth: wrong key | 401 | 401 -- PASS |
| Auth: wrong content-type | 415 | 415 -- PASS |
| Auth: malformed JSON | -32700 | -32700 -- PASS |
| get_trip_status (started) | success with trip data | success, Iceland Road Trip data returned -- PASS |
| create_journal_entry (finished) | "not writable" error | "Trip 'Japan Spring Tour' is not writable (state: finished)" -- PASS |
| Unknown tool name | error response | -32602 "Tool not found: nonexistent_tool" -- PASS |
| Wrong JSON-RPC method | "Method not found" | -32601 "Method not found" -- PASS |

---

## Mobile (393x852)

Mobile viewport testing was **not possible** in this environment. The `agent-browser viewport` command is not available and `agent-browser device` requires Xcode/iOS simulators which are not installed on this Linux host.

**Recommendation:** This feature adds no UI changes (no new views, forms, buttons, or visible elements). The remember feature operates entirely at the cookie/session level. Mobile testing is not applicable for this change.

---

## Summary

The implementation is clean and follows Rodauth conventions. There is **one defect** (D1: `remember_period` mismatch) that should be fixed before merge -- it is a one-line addition. The edge case gaps are all low severity and can be addressed in follow-up work.

### Verdict: Fix D1, then ready to merge.
