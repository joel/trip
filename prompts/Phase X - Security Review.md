# Security Review -- feature/remember-persistent-sessions

**Date:** 2026-04-01
**Reviewer:** Claude Opus 4.6 (adversarial security pass)
**Scope:** `git diff main...HEAD` (6 files, +72 lines)
**Branch:** `feature/remember-persistent-sessions`
**Issue:** #64 -- Enable Rodauth :remember feature for persistent sessions

---

## Checklist Summary

| Category | Status |
|---|---|
| Authentication & Authorization | PASS |
| Input & Output | N/A |
| Data Exposure | PASS |
| Mass Assignment & Query Safety | N/A |
| Secrets & Configuration | PASS |
| Dependencies | N/A |

---

## Critical (must fix before merge)

No critical issues found.

---

## Warning (should fix or consciously accept)

### W-1: Logout does not remove the server-side remember key from the database

**File:** `app/misc/rodauth_main.rb` (no explicit `after_logout` hook)
**Rodauth source:** `rodauth-2.43.0/lib/rodauth/features/remember.rb:241-244`

When a user logs out, Rodauth's built-in `after_logout` hook in the remember feature calls `forget_login`, which **only deletes the remember cookie** from the browser. It does **not** call `remove_remember_key`, so the token row persists in `user_remember_keys` until it expires naturally (30 days after creation or last extension).

**Why it matters:** If an attacker obtains a copy of the remember cookie value (e.g., via physical access to the device before the user logs out, browser data export, or a compromised backup), they could replay the cookie against the server even after the legitimate user has logged out. The server would accept it because the DB record is still valid. This is a session fixation-adjacent risk: the user believes they have revoked their session by logging out, but the server-side token remains usable.

**Severity context:** This is Rodauth's **default behavior** and is by design -- Rodauth treats the cookie as the sole bearer credential, and clearing it from the browser is considered sufficient. Many applications accept this tradeoff. However, for defense-in-depth, especially in an app where users may log in from shared or semi-trusted devices, invalidating the DB record on logout provides a stronger guarantee.

**Suggested fix (if accepted):**

```ruby
after_logout do
  forget_login        # clear cookie (Rodauth default, already called by super)
  remove_remember_key # also remove the DB row so the token cannot be replayed
  super
end
```

Note: `after_logout` in the remember feature already calls `forget_login`, so adding an explicit `after_logout` in `rodauth_main.rb` would override it. The implementation would need to call both `forget_login` and `remove_remember_key`, then `super` to chain any additional logout hooks.

**Risk if deferred:** Low-to-medium. Exploiting this requires the attacker to have already captured the raw cookie value, which is protected by httponly + secure flags. The 30-day expiry provides a natural ceiling. The risk is primarily theoretical in environments with HTTPS-only access and no shared devices.

### W-2: The `/remember` settings endpoint is exposed to authenticated users

**File:** `app/misc/rodauth_main.rb:9` (`:remember` in the `enable` list)

Enabling the `:remember` feature automatically registers a `/remember` route via `r.rodauth`. This exposes a form where authenticated users can change their remember setting (remember, forget, disable). While the route is protected by `require_account` (Rodauth's built-in authentication check), the UI of this application does not link to this page anywhere.

**Why it matters:** An undiscovered, unlinked route that mutates authentication state is a minor attack surface concern. A user (or attacker with a valid session) could visit `/remember` directly and change settings. In this case the impact is minimal -- the worst case is a user disabling their own remember-me. However, hidden routes that are not tested or monitored can become blind spots.

**Options:**
1. **Accept as-is** -- the route is harmless and authenticated-only.
2. **Disable the route** while keeping the feature's methods available:
   ```ruby
   remember_route false
   ```
   This would disable the GET/POST `/remember` endpoint while still allowing `remember_login`, `forget_login`, `load_memory`, etc. to work programmatically.

**Risk if deferred:** Very low. The route only allows self-service changes to the user's own remember setting.

---

## Informational (no action required)

### I-1: Cookie security attributes are correctly set by default

Rodauth's remember feature (`rodauth-2.43.0/lib/rodauth/features/remember.rb:186-193`) sets the following cookie attributes automatically:

- **httponly: true** (line 191) -- prevents JavaScript access to the cookie, mitigating XSS-based cookie theft
- **secure: true** when `request.ssl?` (line 192) -- ensures the cookie is only sent over HTTPS
- **path: "/"** (line 190) -- scopes the cookie to the entire application

The production environment has `config.force_ssl = true` and `config.assume_ssl = true` (`config/environments/production.rb:31,34`), which ensures `request.ssl?` returns `true` and the secure flag is always set in production. In development, the application runs behind an HTTPS-terminating proxy (`https://catalyst.workeverywhere.docker`), so the secure flag is also set.

**Note:** Rodauth does **not** set a `SameSite` attribute on the remember cookie by default. Modern browsers default to `SameSite=Lax` when no attribute is specified, which provides adequate CSRF protection for the cookie. This is acceptable.

### I-2: Token storage model is sound

The `user_remember_keys` table uses:
- **UUID primary key** (`t.uuid :id, primary_key: true`) that is also the foreign key to `users` -- this is a one-to-one relationship (one remember key per user), consistent with Rodauth's design
- **`key` column** (`string`, `null: false`) -- stores the server-side remember token
- **`deadline` column** (`datetime`, `null: false`) -- stores the expiry timestamp
- **Foreign key constraint** (`t.foreign_key :users, column: :id`) -- ensures referential integrity and cascading cleanup when the user is deleted

Rodauth's `active_remember_key_ds` method (`remember.rb:265-266`) filters by `deadline > CURRENT_TIMESTAMP`, so expired tokens are automatically rejected even if not yet cleaned up from the database.

### I-3: `remember_login` is called unconditionally in `after_login`

**File:** `app/misc/rodauth_main.rb:139`

Every successful login (email auth, WebAuthn, OmniAuth) triggers `remember_login`, which sets a 30-day remember cookie. There is no opt-in/opt-out UI -- all users get persistent sessions automatically.

This is a deliberate design choice (per the issue description) and is common in consumer-facing applications. The tradeoff is convenience vs. security on shared devices. Users who want to end their session must explicitly log out. The `after_logout` hook's `forget_login` call (from Rodauth's remember feature) correctly clears the cookie on logout.

### I-4: `load_memory` placement is correct

**File:** `app/misc/rodauth_app.rb:8`

`rodauth.load_memory` is called inside the Roda route block, before `r.rodauth`. This is the correct placement per Rodauth's documentation -- it runs on every request that hits the Rodauth middleware, checking for a valid remember cookie and auto-logging the user in if the session has expired but the cookie is still valid.

The `extend_remember_deadline? true` setting causes `load_memory` to also extend the deadline on each request when the user is already logged in (via `extend_remember_deadline_while_logged_in?`), effectively implementing a sliding window. The extension only happens once per `extend_remember_deadline_period` (default: 3600 seconds / 1 hour), not on every single request.

### I-5: No stale remember keys cleanup mechanism

The `user_remember_keys` table will accumulate expired rows over time. Rodauth does not provide an automatic cleanup job for expired remember keys. The `active_remember_key_ds` method filters them out at query time, so expired rows have no functional impact, but they do consume disk space.

This is a minor operational concern, not a security issue. A periodic cleanup job (e.g., `DELETE FROM user_remember_keys WHERE deadline < NOW()`) could be added in a future maintenance phase.

### I-6: Migration uses `id: false` with explicit UUID primary key

**File:** `db/migrate/20260401174314_create_user_remember_keys.rb:3-4`

The migration uses `id: false` and then defines `t.uuid :id, primary_key: true`. This creates a UUID primary key that doubles as the foreign key to `users`. This is the standard pattern in this project for Rodauth key tables (consistent with `user_verification_keys`, `user_email_auth_keys`, `user_webauthn_user_ids`).

---

## Not applicable

| Category | Reason |
|---|---|
| Input & Output | No user-facing views, forms, or params handling introduced. The remember cookie is set/read entirely by Rodauth internals. No new Phlex components. No `unsafe_raw` usage. |
| Mass Assignment & Query Safety | No controllers or models modified. No user-supplied params. All DB operations are internal to Rodauth (parameterized Sequel queries). |
| File uploads | No file upload handling in this diff. |
| Dependencies | No new gems added to `Gemfile` or `Gemfile.lock`. |
| Secrets & Configuration | No new secrets, env vars, or credentials files. No hardcoded tokens. |
| Invitation/token flows | The remember token is managed entirely by Rodauth -- generated server-side, stored in DB, delivered via httponly/secure cookie. No user-facing token input. |

---

## Rodauth Remember Feature -- Security Properties Summary

| Property | Status | Details |
|---|---|---|
| Cookie httponly | Yes | Set by default in `_set_remember_cookie` (line 191) |
| Cookie secure | Yes (in production) | Set when `request.ssl?` is true (line 192); `force_ssl = true` in production |
| Cookie SameSite | Lax (browser default) | Not explicitly set; modern browsers default to Lax |
| Token storage | Server-side DB | `user_remember_keys.key` column; never exposed to client |
| Cookie value | `{user_id}_{hmac(key)}` | HMAC-signed when `hmac_secret` is configured; raw key otherwise |
| Deadline enforcement | Server-side | `active_remember_key_ds` filters by `deadline > CURRENT_TIMESTAMP` |
| Deadline duration | 30 days | Configured via `remember_deadline_interval({ days: 30 })` |
| Sliding window | Yes | `extend_remember_deadline? true` extends on activity (max once/hour) |
| Logout clears cookie | Yes | `after_logout` calls `forget_login` (deletes cookie) |
| Logout clears DB record | No | See Warning W-1 |
| Account deletion clears DB | Yes | `after_close_account` calls `remove_remember_key` (line 246-248) |

---

## Conclusion

The implementation is secure for merge. The remember feature is configured correctly, following Rodauth's documented patterns and the project's established conventions for table naming and UUID primary keys. Cookie security attributes (httponly, secure) are set automatically by Rodauth. The `load_memory` call is correctly placed in the Roda route block.

The two warnings are low-risk and can be addressed before or after merge at the team's discretion:

- **W-1** (DB record not cleared on logout) is Rodauth's default behavior and is acceptable for most applications. Adding `remove_remember_key` to `after_logout` would strengthen defense-in-depth.
- **W-2** (exposed `/remember` route) can be disabled with `remember_route false` if the team prefers not to expose the settings form.

No critical issues were found. No new attack surface was introduced beyond the standard Rodauth remember feature behavior.
