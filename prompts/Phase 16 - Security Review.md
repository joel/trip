# Phase 16 — Security Review

**Branch:** `feature/phase16-onboarding-improvements`
**PR:** [#103 — Phase 16: Onboarding improvements](https://github.com/joel/trip/pull/103)
**Base:** `main` (clean, `git status` empty)
**Reviewer mode:** Adversarial. Assumes the attacker has read access to source and full interactive access to the running site.
**Tooling:** Brakeman 8.0.4 (clean), bundle-audit against ruby-advisory-db commit `b1e3c15a` (clean).
**Live target:** `https://catalyst.workeverywhere.docker/` (container `catalyst-app-dev`).

---

## Executive Summary

| Severity | Count | Items |
|----------|-------|-------|
| Critical / Broken / Defect | 0 | -- |
| High | 2 | Account enumeration via `/login` redirect; Account enumeration via `/request-access` response differentiation |
| Medium | 2 | Login case-sensitivity regression; Pre-existing `new_account` duplicate-check leak (amplified by Phase 16) |
| Low | 2 | Invitation email not normalised on `Invitation` model; Verify-account hook redundantly calls `generate_verify_account_key_value` |
| Verified OK | 9 | Invitation-token bypass attempts; autologin gate; CSRF; Brakeman; bundle-audit; MCP endpoint; SQL injection; secrets; migration integrity |

**No blocking Critical findings.** Two High findings are attacker-usable information disclosure (account enumeration). They don't grant unauthorised access, but they convert the login surface into a user-registry oracle. Given the product is explicitly invite-only and the registered user base is small, enumeration is a more serious concern here than in a typical SaaS -- knowing which emails are registered is a targeted-phishing primer. Fix before merge recommended.

Severity key used below: Critical -- Broken / Defect; High; Medium; Low; Verified OK.

---

## Methodology

1. Diffed `main...HEAD` to scope the review to Phase 16 changes only (~700 LOC outside `prompts/`).
2. Read the full `rodauth_main.rb`, `AccessRequest`, `AccessRequests::Submit`, and the new migration.
3. Traced Rodauth 2.43 internals (`rodauth-2.43.0/lib/rodauth/features/{base,login,create_account,verify_account}.rb`) to confirm call ordering.
4. Ran `mise x -- bundle exec brakeman --no-pager` and `mise x -- bundle exec bundle-audit check --update`.
5. Grepped the diff for hard-coded secrets/tokens/API keys.
6. Executed live black-box tests against the dev site with `curl` to probe the enumeration, autologin-bypass, email-mismatch, and CSRF surfaces. Seeded invitations and users directly in the container via `bin/rails runner`.
7. Cleaned up all test artifacts from the dev DB.

---

## High -- Finding 1: Account enumeration oracle on `POST /login`

**OWASP:** A01 Broken Access Control (information exposure) -- A07 Identification & Authentication Failures.

**Where:** `app/misc/rodauth_main.rb:76-85`

```ruby
before_login_route do
  next unless request.post?

  login_value = param_or_nil(login_param)
  next if login_value.blank?
  next if _account_from_login(login_value)

  set_redirect_error_flash "Invitation required. Request access below."
  redirect "/"
end
```

**Problem:**
The hook produces a **binary** response differential that an unauthenticated attacker can query at rate:

- **Known email** (`_account_from_login` hits) -> HTTP **200**, body ~18 KB (multi-phase login page rendering "Continue for {email}").
- **Unknown email** -> HTTP **302** redirect to `/` with body size `0`.

Before Phase 16 the differential existed but was softer: both responses landed on `/login` with a different flash text -- distinguishable but at least same-URL / same-template. The `before_login_route` redirect makes the difference trivially scriptable (different HTTP status, different `Location` header, different body size, ~10 ms per probe).

**Proof (live):**

```
known email   -> HTTP=200  time~=0.02s  size=18516B
known email   -> HTTP=200  time~=0.02s  size=18537B
known email   -> HTTP=200  time~=0.02s  size=18558B
unknown email -> HTTP=302  time~=0.01s  size=0B
unknown email -> HTTP=302  time~=0.01s  size=0B
unknown email -> HTTP=302  time~=0.01s  size=0B
```

A rate-limited scanner can check millions of emails against this endpoint and classify each as "has an account" or "does not". For an invite-only product this inverts the security model -- the whole point of the invite gate is that the user base is not public knowledge.

**Suggested fixes (pick one or more):**

1. **Uniform response shape (recommended):** keep the redirect but also redirect known emails with a generic flash like "Sign-in link sent if the account exists" and do the real multi-phase login page only after the user clicks a link sent to their email. Rodauth's `:email_auth` feature fits here.
2. **Soft differential:** on unknown-email POST, re-render the same multi-phase login view (same template, same 200 status) but with a generic flash "If an account exists for this email, you can continue below." Do not include the email value in the response body.
3. **Rate-limit the `/login` POST endpoint** by IP + sliding window + exponential backoff. Combined with CAPTCHA after N failed attempts, this reduces the practical enumeration throughput to near-zero. (Independent of fixes 1/2, still worth doing.)

---

## High -- Finding 2: Account enumeration oracle on `POST /request-access`

**OWASP:** A01 Broken Access Control (information exposure) -- A04 Insecure Design.

**Where:** `app/models/access_request.rb:22-34` and `app/actions/access_requests/submit.rb:18-21`

```ruby
def email_not_already_registered
  return if email.blank?
  return unless User.exists?(["LOWER(email) = ?", email])

  errors.add(:email, "is already registered -- please sign in")
end
```

**Problem:**
The form renders distinct, unique inline error messages depending on account state:

| Submission state | HTTP | Visible body text |
|-------------------|------|-------------------|
| New email (no record) | 302 | "Your access request has been submitted" (success toast) |
| Email already has pending/approved `AccessRequest` | 422 | "already has a pending request or approved invitation" |
| Email belongs to an existing `User` | 422 | "Email is already registered -- please sign in" |

**Proof (live):**

```
unknown email          -> HTTP=302
registered-user email  -> HTTP=422  body contains "Email is already registered -- please sign in"
pending-request email  -> HTTP=422  body contains "already has a pending request"
```

This is worse than Finding 1 because even a single probe is enough: the attacker gets a plain-text English label of the account's state. Three attempts with the same email also classify it as pending->registered->rejected over time, exposing the admin's workflow.

**Trade-off caveat:** the helpful error message is intentional UX -- it tells a returning user "you already have an account, sign in instead." That UX value is real. The compromise is to keep the UX for *known* invitation surfaces (e.g., the `/create-account` page where the user came from an email link) but make the public `/request-access` form generic.

**Suggested fix:**

- Public-form path: always return the **same** success message regardless of whether the email is new, pending, approved, rejected, or already a user. For legitimate duplicates, silently no-op in the background and send an email to the address ("Hey, you already have access -- here's a link to sign in"). This preserves UX while denying enumeration.
- Keep the **model-level** validations as-is (they are correct and prevent state corruption). Only the controller/view should suppress the differential response.
- Optionally rate-limit `/request-access` POSTs by IP to slow mass probing even of the uniform response.

---

## Medium -- Finding 3: Login case-sensitivity regression for existing users

**OWASP:** A04 Insecure Design (defect/usability with security implications).

**Where:** `app/misc/rodauth_main.rb:79-84` and Rodauth's default `_account_from_login` at `rodauth-2.43.0/lib/rodauth/features/base.rb:801-806`.

**Problem:**
`_account_from_login(login)` does `where(login_column => login)` -- a case-sensitive equality check in SQLite. `User` has no `before_validation :normalize_email` (see `app/models/user.rb:28`). So a user stored as `alice@acme.org` who types `Alice@Acme.Org` at login is **not** found by `_account_from_login`. The hook then redirects them to `/` with flash "Invitation required. Request access below." -- which is false and misleading.

**Proof (live):**

```
email=alice@acme.org -> HTTP 200 (multi-phase login page renders)
email=Alice@Acme.Org -> HTTP 302 /  "Invitation required"
```

**Security impact:** low (does not grant unauthorised access -- the user just can't log in). But the response identical to "unknown email" pushes legitimate case-mismatched users into the "request access" funnel, where they'll submit an AccessRequest for an email that already has a User -> Finding 2 exposes "Email is already registered -- please sign in". Loop closed: attacker learns case-different variant was stored.

**Suggested fix:**

1. **Add `normalizes :email, with: ->(e) { e.downcase.strip }` to `User` model** (Rails 7.1+ normaliser; runs on read and write, so existing rows are also matched on lookup).
2. Either:
   - Override Rodauth's `normalize_login` to `.downcase.strip`, so `_account_from_login` and all other lookups go through the same normalised value, **or**
   - Override `_account_from_login` to do a case-insensitive lookup (`.where("LOWER(email) = ?", login.downcase)`).
3. Backfill existing `users.email` with `UPDATE users SET email = LOWER(TRIM(email))` to avoid the `Invitation.email.downcase == email.to_s.downcase` mismatch in `validate_invitation_token`.

---

## Medium -- Finding 4: Pre-existing Rodauth duplicate-login oracle, amplified by Phase 16

**OWASP:** A07 Identification & Authentication Failures.

**Where:** Rodauth `verify_account.rb:187-194` `new_account(login)` inherited behaviour; interacts with Phase 16's `account_initial_status_value` override.

**Problem:**
Rodauth's `:verify_account` feature overrides `new_account(login)`:

```ruby
if account_from_login(login) && allow_resending_verify_account_email?
  set_response_error_reason_status(:already_an_unverified_account_with_this_login, ...)
  set_error_flash attempt_to_create_unverified_account_error_flash
  return_response resend_verify_account_view
end
super
```

If a registered user (verified, status 2) re-submits `create-account` with their own email + any `invitation_token`, Rodauth returns HTTP **403** and the `resend_verify_account_view`, which **pre-fills the email input with the submitted value** and tells the attacker "The account you tried to create is currently awaiting verification". This reveals that the email is a known-to-Rodauth account (status 1 OR 2). Phase 16 did not introduce this, but it is now on the attacker's enumeration toolbelt next to Findings 1 and 2.

**Proof (live):**

```
Attack 5: valid token for 'preexisting@acme.org' + that user already exists
-> HTTP=403
-> body flash: "The account you tried to create is currently awaiting verification"
-> body pre-fills: value="preexisting@acme.org"
```

**Suggested fix:**
Override `new_account(login)` to suppress the resend view when `param_or_nil("invitation_token").present?` (invited-signup context). Redirect to `/` with a generic flash "Unable to complete signup with the provided invitation." The existing-account path should not leak; on a valid invitation you can silently log the collision for admin review.

This is a Phase-16-adjacent hardening -- the override window is the one Phase 16 is already using for other hooks (`account_initial_status_value`, `create_verify_account_key`, etc.), so the fix sits naturally in the same `auth_class_eval` block.

---

## Low -- Finding 5: `Invitation` model does not normalise email

**Where:** `app/models/invitation.rb`

The `Invitation` model does not `before_validation :normalize_email`. A superadmin sending an invitation to `Alice@Acme.Org` stores it literally. The `validate_invitation_token` hook does `.downcase == .downcase` which rescues the mismatch, but for consistency and to match `AccessRequest#normalize_email` added in Phase 16, the Invitation model should do the same. Also lets the `Invitation.valid_tokens.find_by(email: ...)` queries elsewhere be case-consistent.

**Suggested fix:** add `before_validation { self.email = email.to_s.downcase.strip.presence }` to `Invitation` and backfill existing rows.

---

## Low -- Finding 6: Verify-account key generation still runs for invited signups

**Where:** `app/misc/rodauth_main.rb:138-148`

```ruby
def create_verify_account_key
  return if param_or_nil("invitation_token").present?
  super
end

def send_verify_account_email
  return if param_or_nil("invitation_token").present?
  super
end
```

`create_verify_account_key` and `send_verify_account_email` are correctly short-circuited. However, `generate_verify_account_key_value` (called from `setup_account_verification`, see `verify_account.rb:237-241`) still executes and generates a random key that is never used. This wastes a small amount of entropy per invited signup and creates an unused `@verify_account_key_value` ivar. Not a security issue, but worth cleaning up.

**Suggested fix:** override `setup_account_verification` to no-op when `invitation_token` is present. Or keep the current skip-at-`create_verify_account_key` behaviour and accept that the random value is harmlessly discarded.

---

## Verified OK

### Verified -- Invitation-token bypass attempts all rejected

Attack matrix (all performed live against `https://catalyst.workeverywhere.docker`):

| # | Input | Expected | Actual | Verdict |
|---|-------|----------|--------|---------|
| 1 | Valid token for `fresh-invitee@acme.org` + email `attacker@evil.com` | Reject | 302 -> `/`, no user created | PASS |
| 2 | `invitation_token=NOT_A_REAL_TOKEN_BOGUS` + any email | Reject | 422, no user created | PASS |
| 3 | Valid token + matching email (positive control) | Create user `status=2`, autologin | User created, `status=2`, invitation `accepted` | PASS |
| 4 | Invitation stored `MixedCase@Acme.Org`, submit lowercase | Accept (equal after downcase) | User created with submitted case | PASS (but `Invitation` email case not normalised -- see Finding 5) |
| 5 | Valid token for `preexisting@acme.org` when that user already exists | Reject or redirect | 403 `resend_verify_account_view` (see Finding 4) | PASS (no double-account) |
| 6 | Bogus `invitation_token=BOGUSFAKE` + `email=bogus-attempt@acme.org` | Reject | 302 -> `/`, no user, no autologin | PASS |

The `validate_invitation_token` hook in `before_create_account` throws `request.redirect` which is a Roda halt, so `save_account`, `account_initial_status_value`, `after_create_account`, and `create_account_autologin?` never run when the token is missing, invalid, or mismatched. The "autologin" surface is strictly gated by a passing invitation validation.

### Verified -- No hard-coded secrets in the diff

```
git diff main...HEAD | grep -E "(bearer|api[_-]?key|secret.*=|password.*=|token.*=.*['\"])" | grep -v prompts/
# -> no output
```

Clean. All credentials are read from `ENV`.

### Verified -- CSRF protection enforced on all new flows

Live black-box tests with no `authenticity_token`:

| Endpoint | HTTP | Result |
|----------|------|--------|
| `POST /request-access` | 422 | `ActionController::InvalidAuthenticityToken` |
| `POST /login` | 422 | `ActionController::InvalidAuthenticityToken` |
| `POST /create-account` | 422 | `ActionController::InvalidAuthenticityToken` |

All inherit Rails CSRF protection via `RodauthController < ApplicationController < ActionController::Base`.

### Verified -- Brakeman scan clean

```
== Brakeman Report ==
Rails Version: 8.1.3
Brakeman Version: 8.0.4
Security Warnings: 0
Ignored Warnings: 5
```

No new warnings attributable to Phase 16.

### Verified -- bundle-audit clean

```
ruby-advisory-db commit b1e3c15a (2026-03-30)
No vulnerabilities found
```

### Verified -- No SQL injection in new code

- `email_not_already_registered`: uses `User.exists?(["LOWER(email) = ?", email])` -- bound parameter. Safe.
- Migration `reconcile_duplicate_active_requests`: static SQL, no interpolation of any value except database columns. Safe.
- `AccessRequests::Submit` uses `AccessRequest.create!(email: params[:email])` -- ActiveRecord sanitises. Safe.

### Verified -- MCP endpoint is NOT touched or weakened

```
git diff main...HEAD --name-only | grep -i mcp   -> (empty)
git diff main...HEAD -- app/controllers/mcp_controller.rb app/tools/   -> (empty)
```

`McpController#authenticate_api_key!` is unchanged; `secure_compare` protection, `blank?` key gate, and `head :unauthorized` responses are all intact. The `MCP_API_KEY` scope is unchanged.

### Verified -- Phlex output is auto-escaped

No new `unsafe_raw` / `raw safe(...)` usage introduced by Phase 16 (the existing `raw safe(...)` in `app/views/rodauth/create_account.rb:30` for `create_account_additional_form_tags` is pre-existing and contains Rodauth-generated hidden fields, not user input).

### Verified -- Migration integrity

- Data-modification step (`reconcile_duplicate_active_requests`) is idempotent: re-running it is a no-op (the UPDATE has nothing to update after the partial unique index is in place).
- `down` correctly removes the index only. Note: the `down` does **not** restore the `pending`/`approved` rows that were marked `rejected` during `up`. This is called out explicitly in the migration comment ("Deletions are avoided so the original submission history is preserved"), but `down` will leave those rows in `rejected` status. Acceptable trade-off -- a proper down would require snapshotting state, which is overkill for a schema migration.
- SQLite compatibility: partial unique indexes are supported since SQLite 3.8.0 (2013), covered by Rails 8.1's `add_index` syntax.

### Verified -- Normalisation ordering is correct

`before_validation :normalize_email` runs before the `validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }` check in `AccessRequest`. A whitespace-only email becomes `nil` -> fails presence. Verified live: `AccessRequest.new(email: '   ').valid? -> false, errors: ["can't be blank", "is invalid"]`.

---

## OWASP Coverage

| Category | Covered | Notes |
|----------|---------|-------|
| A01 -- Broken Access Control | Yes | Findings 1 and 2 (account enumeration); verified `authorize!` in AccessRequestsController unchanged. |
| A02 -- Cryptographic Failures | Yes | No new crypto. `SecureRandom.uuid`, `has_secure_token :token`, `secure_compare` unchanged. |
| A03 -- Injection | Yes | Diff grep + manual review. No raw SQL with interpolated input. `LOWER(email) = ?` is parameter-bound. Migration is static SQL. |
| A04 -- Insecure Design | Yes | Findings 2 and 3. The friendly error strings are intentional UX but create side channels. |
| A05 -- Security Misconfiguration | Yes | No config changes affect runtime. Migration behaves correctly. CSRF preserved. |
| A06 -- Vulnerable and Outdated Components | Yes | bundle-audit clean. No new gems in `Gemfile` diff. |
| A07 -- Identification & Authentication Failures | Yes | Findings 1, 3, 4. Invitation-token bypass attempts all fail. Autologin is token-gated. |
| A08 -- Software and Data Integrity Failures | Yes | `has_secure_token` tokens unchanged. `after_create_account` only runs with a validated token. |
| A09 -- Security Logging and Monitoring Failures | Yes | `Rails.event.notify("access_request.submitted", ...)` emits `email:` in plaintext in the payload. Acceptable -- used for admin notification subscriber. No password/token is logged. |
| A10 -- SSRF | N/A | No URL fetches introduced. |

---

## Consolidated Defect List

### Critical / Broken / Defect

*(none -- Phase 16 introduces no blocking regressions)*

### High -- recommended before merge

- [ ] **Finding 1** -- eliminate HTTP-status / body-size differential on `POST /login` between known and unknown emails (`app/misc/rodauth_main.rb:76-85`). Recommended: either (a) uniform-redirect all submissions with a generic flash + rate-limit, or (b) keep multi-phase-login same-template response for unknown emails without echoing the value back.
- [ ] **Finding 2** -- remove "is already registered -- please sign in" / "already has a pending request" from the public `/request-access` response (`app/models/access_request.rb:22-34`, `app/views/access_requests/new.rb`). Always show the same success message; notify legitimate duplicates via email instead.

### Medium -- fix before next phase

- [ ] **Finding 3** -- normalise `User.email` to lowercase-stripped; override Rodauth `normalize_login` and backfill existing rows.
- [ ] **Finding 4** -- override Rodauth `new_account(login)` to suppress the "awaiting verification" resend view when `invitation_token` is present.

### Low -- defer to cleanup PR

- [ ] **Finding 5** -- add `before_validation :normalize_email` to `Invitation`.
- [ ] **Finding 6** -- override `setup_account_verification` (or remove the redundant key generation) when `invitation_token` is present.

---

## Appendix -- Test Artifacts Created & Cleaned Up

During live probing, the following were created in the dev database and **all removed** after the review:

- Users: `token-victim@acme.org`, `fresh-invitee@acme.org`, `preexisting@acme.org`, `attacker@evil.com`, `attacker2@evil.com`, `bogus-attempt@acme.org`, `mixedcase@acme.org`.
- Invitations: three (`fresh-invitee@acme.org`, `preexisting@acme.org`, `MixedCase@Acme.Org`).
- AccessRequests: all matching `pending-test-%` and `freshly-enumerated-%`.

Cleanup verified by follow-up `User.where(...).count == 0`.

---

**Review completed 2026-04-18 by Claude Opus 4.7 (1M context) acting as an adversarial security reviewer.**

---

## Skill Self-Evaluation

**Skill used:** security-review

**Step audit:**

- The SKILL.md does not include an explicit live-runtime probe step (only `brakeman`, `bundle-audit`, and code-level checklist); I added live `curl` probes because the user brief asked for concrete exploitation proof on enumeration and invitation-token bypass. This was a deliberate and necessary addition, not a deviation.
- The SKILL.md's "Output Format" section lists severity categories Critical/Warning/Informational/Not applicable. The user's brief required Critical/High/Medium/Low/Verified OK and an OWASP mapping; I followed the user's format (overrides default SKILL.md format).
- The SKILL.md says "If no issues are found, state that explicitly -- a clean bill of health is a valid outcome." I reported High findings with proof; not applicable here.
- No step was skipped except the "Fixing Issues" last section (`open a fix inline before the PR is created. Follow the github-workflow commit conventions`). I did not apply fixes because the user asked for a review report only, not a fix pass. This was a user-instructed deviation.

**Improvement suggestion:** Add a "Live probe" checklist category to SKILL.md for auth-touching diffs, with example curl commands for enumeration testing. Current SKILL.md checklist is purely code-reading; phase-16 demonstrates that enumeration vectors only become obvious once you observe the HTTP response differentials at the wire level. A suggested new checklist bullet: "For any auth/login/account-status change, black-box the POST endpoint with at least one known and one unknown credential; report the HTTP status, response body length, and `Location` header for each."
