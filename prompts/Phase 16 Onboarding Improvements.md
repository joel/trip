# Phase 16: Onboarding Improvements

**Status:** Draft
**Date:** 2026-04-18
**Confidence Score:** 9/10 (all five issues are well-bounded, all touch files we own, and every change has a clear Rodauth hook or ActiveRecord validation path)

---

## 1. Context

The invite-only onboarding flow was built in Phase 2 and has been live through Phase 15. Real-world usage has surfaced five UX/bug issues that make the entry experience confusing for first-time visitors and leaky for returning admins.

**The five issues to fix, in the user's own words:**

1. **Two panels on the homepage are confusing.** Logged-out visitors see an "Access → Request an invitation" card *and* a "Returning? → Sign in" card. People naturally click "Sign in" and hit a dead end because they have no account yet. The `Sign in` link in the sidebar already exists, so the second panel is redundant.

2. **"There was an error logging in / No matching login"** is Rodauth boilerplate and doesn't explain the actual situation: the user has no account and needs an invitation. The redirect target should be the home page, with a helpful flash.

3. **"A valid invitation is required to create an account"** is also cryptic and the current redirect loops back to `/create-account`, which is the exact page that just rejected them. The redirect should go home with the same helpful flash.

4. **Duplicate access requests bug.** `AccessRequest` has no uniqueness guard. The same email can submit a new request after approval, rejection, or while one is still pending. This lets users spam the inbox and creates audit noise.

5. **Verify Account step is redundant.** The invitation email already proves the user controls their email (they clicked a tokenised link sent to that address). Making them verify again after signup is friction for no gain — they should be auto-logged-in on account creation.

---

## 2. Reference Documentation

| Resource | URL |
|----------|-----|
| Rodauth Login Feature | https://rodauth.jeremyevans.net/rdoc/files/doc/login_rdoc.html |
| Rodauth Create Account Feature | https://rodauth.jeremyevans.net/rdoc/files/doc/create_account_rdoc.html |
| Rodauth Verify Account Feature | https://rodauth.jeremyevans.net/rdoc/files/doc/verify_account_rdoc.html |
| Rodauth Internals (auth_class_eval) | https://rodauth.jeremyevans.net/rdoc/classes/Rodauth/Auth.html |
| `create_account_autologin?` (Rodauth auth value method) | https://rodauth.jeremyevans.net/rdoc/files/doc/create_account_rdoc.html#label-Auth+Value+Methods |
| Rails 8.1 Guides — Validations (uniqueness, conditional) | https://guides.rubyonrails.org/active_record_validations.html#uniqueness |
| Phlex Rails Components | https://www.phlex.fun/rails |
| Action Policy | https://actionpolicy.evilmartians.io/ |

---

## 3. Scope

### What this phase changes

1. **Homepage (logged-out):** remove the "Sign in" card. The access card becomes the single, centred call-to-action.
2. **Login flow:** when a visitor submits an email that has no matching account, redirect to `/` with a flash explaining that an invitation is required — not the default "No matching login" error re-rendered on the login form.
3. **Create-account gate:** when the invitation token is missing or invalid, redirect to `/` (instead of `/create-account`) with the same flash.
4. **Access request duplication:** block new submissions for emails that already have a `pending` or `approved` request, or that already belong to an existing `User`. Allow resubmission only if the prior request was `rejected`.
5. **Account creation flow:** for users created through a valid invitation, mark the account as verified at creation time, skip the verification email, and auto-log them in. Redirect to the root path.

### What this phase does NOT change

- The verify_account feature stays **enabled** in Rodauth (needed as a safety net for any future non-invitation signup path, e.g. admin-created users who set their own login, and for migration of any existing unverified accounts).
- The `/request-access` public form stays as-is visually; only its server-side validation tightens.
- Access request approval → invitation sending → email delivery pipeline is untouched.
- The sidebar "Sign in" / "Create account" nav items for logged-out visitors stay in place (users still have a way to sign in without the homepage panel).
- No changes to Passkeys, Google One-Tap, email-auth, or the multi-phase login flow itself.
- No changes to the `users` table schema. Invited accounts will be persisted with `status = 2` (open/verified) via Rodauth's status column, same as any verified account today.

---

## 4. Existing Codebase Context

### Relevant files and what they currently do

| File | Current behaviour |
|------|------------------|
| `app/views/welcome/home.rb` | `render_logged_out` renders a `md:grid-cols-2` with `render_access_card` and `render_signin_card`. |
| `app/misc/rodauth_main.rb` | `before_create_account` calls `validate_invitation_token`, which on failure redirects to `create_account_path`. `after_create_account` calls `Invitations::Accept` but does **not** auto-verify or auto-login. `verify_account_view` is overridden to auto-verify + auto-login when the user clicks the email link. |
| `app/controllers/access_requests_controller.rb` | `#create` calls `AccessRequests::Submit.new.call(params:)` — no pre-check for duplicates or existing users. |
| `app/models/access_request.rb` | Validates presence + format of `email`. No uniqueness validation, no existing-user check. |
| `app/actions/access_requests/submit.rb` | `persist` calls `AccessRequest.create!(email: params[:email])`. Any `RecordInvalid` bubbles up as `Failure(errors)`. |
| `db/migrate/20260322093251_create_access_requests.rb` | Adds a **non-unique** index on `email`. |
| `app/components/rodauth_login_form.rb` | Renders email-only form to `/login`. On failure, Rodauth re-renders with a `no_matching_login` flash. |
| `app/views/rodauth/create_account.rb` | Has `render_invitation_token_field` that preserves the token through POST and `invitation_email` that locks the email field when a valid invitation is found. |
| `app/controllers/test_sessions_controller.rb` + `google_one_tap_sessions_controller.rb` | Both already use `rodauth.account_open_status_value` — precedent for the verified-status pattern we'll apply. |
| `spec/system/welcome_spec.rb` | Asserts `have_content("Sign in")` for visitors — will need updating. |

### Rodauth internals worth citing

- **`account_initial_status_value`** — auth-value method returning the integer written to `status` on insert. Default (with verify_account enabled) is `account_unverified_status_value` (1). Overriding it to `account_open_status_value` (2) creates already-verified accounts.
- **`create_verify_account_key` / `send_verify_account_email`** — both run inside the `create_account` transaction. Overriding them to `return` early skips verification-email issuance.
- **`create_account_autologin?`** — auth-value method. When true, Rodauth calls `autologin_session("create_account")` after a successful signup.
- **`before_login_attempt`** — hook fired on POST to `/login` *before* `account_from_login`. At this point `account` is nil; we can call `_account_from_login(login_value)` ourselves to detect the "unknown email" case and redirect before Rodauth sets its generic error flash.
- **`set_redirect_error_flash` + `redirect "/"`** — already used in `validate_invitation_token`; this pattern transfers to the login path unchanged.
- **`rodauth.account_open_status_value`** — returns the integer for "verified/open". Already used by the project in two other places.

---

## 5. Implementation Plan

### Task 1 — Homepage: remove the sign-in card

**File:** `app/views/welcome/home.rb`

- Delete `render_signin_card` method entirely.
- In `render_logged_out`, change the two-column grid to a centred single card. Replace:
  ```ruby
  div(class: "grid gap-6 md:grid-cols-2") do
    render_access_card
    render_signin_card
  end
  ```
  with:
  ```ruby
  div(class: "mx-auto max-w-md") do
    render_access_card
  end
  ```
- `render_access_card` stays; visitors still have the sidebar "Sign in" link as the returning-user path.

### Task 2 — Login: redirect to home when no account matches

**File:** `app/misc/rodauth_main.rb`

Add a `before_login_attempt` hook inside the `configure` block that runs the account lookup pre-emptively and redirects when it returns nil:

```ruby
before_login_attempt do
  login_value = param_or_nil(login_param)
  next if login_value.blank?
  next if _account_from_login(login_value)

  set_redirect_error_flash "Invitation required. Request access below."
  redirect "/"
end
```

Rationale:
- `before_login_attempt` is the first hook on POST `/login`, before Rodauth itself calls `account_from_login`. Doing the lookup here lets us intercept "unknown email" cleanly without touching error_flash internals.
- `_account_from_login` is Rodauth's internal finder (same one `account_from_login` wraps) — it doesn't set `@account`, avoiding state leakage.
- We skip if the value is blank so Rodauth's own blank-field validation still fires (better error).
- We do **not** need to hook `/email-auth` or `/multi-phase-login` — those are only reached after the login form has already validated the account exists.

### Task 3 — Create-account gate: redirect home

**File:** `app/misc/rodauth_main.rb`

In the existing `validate_invitation_token`, change the redirect target and message:

```ruby
def validate_invitation_token
  token = param_or_nil("invitation_token")
  email = param(login_param)
  invitation = token && ::Invitation.valid_tokens.find_by(token: token)
  return if invitation && invitation.email.downcase == email.to_s.downcase

  set_redirect_error_flash "Invitation required. Request access below."
  redirect "/"  # was: redirect create_account_path
end
```

Same flash copy as Task 2 so the homepage message is consistent regardless of entry path.

### Task 4 — Access Request duplication fix

**File:** `db/migrate/<timestamp>_add_unique_index_on_pending_access_request_email.rb` (new)

Add a partial unique index to prevent two *active* (pending or approved) requests for the same email at the database level:

```ruby
class AddUniqueIndexOnActiveAccessRequestEmail < ActiveRecord::Migration[8.1]
  def change
    add_index :access_requests, :email,
              unique: true,
              where: "status IN (0, 1)",
              name: "idx_access_requests_active_email_uniqueness"
  end
end
```

**File:** `app/models/access_request.rb`

Add model-level validations that give friendly error messages before the DB index kicks in:

```ruby
validate :email_not_already_active
validate :email_not_already_registered

private

def email_not_already_active
  return if email.blank?

  scope = self.class.where(email: email, status: %i[pending approved])
  scope = scope.where.not(id: id) if persisted?
  return unless scope.exists?

  errors.add(:email, "already has a pending request or approved invitation")
end

def email_not_already_registered
  return if email.blank?
  return unless User.exists?(email: email)

  errors.add(:email, "is already registered — please sign in")
end
```

**File:** `app/actions/access_requests/submit.rb`

No change in structure — the `Failure(e.record.errors)` path already surfaces the new validation errors to the controller. Add a small guard in `persist` to catch the race where DB constraint rejects after model validation passes (same email submitted twice concurrently):

```ruby
rescue ActiveRecord::RecordNotUnique
  ar = AccessRequest.new(email: params[:email])
  ar.errors.add(:email, "already has a pending request or approved invitation")
  Failure(ar.errors)
```

**File:** `app/controllers/access_requests_controller.rb`

No structural change; the existing `Failure(errors)` branch re-renders the form and the `AccessRequestForm` component already shows the error list.

### Task 5 — Skip Verify Account for invited signups

**File:** `app/misc/rodauth_main.rb`

Three changes inside `auth_class_eval` plus one auth-value-method override:

1. **Create invited accounts as already-verified.** Override `account_initial_status_value`:
   ```ruby
   def account_initial_status_value
     if param_or_nil("invitation_token").present?
       account_open_status_value
     else
       super
     end
   end
   ```

2. **Skip the verify-account key + email for invited signups.** Override both side-effects:
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

3. **Auto-login on invited signup.** Use Rodauth's built-in flag:
   ```ruby
   # outside auth_class_eval, in the configure block
   create_account_autologin? { param_or_nil("invitation_token").present? }
   create_account_redirect { "/" }
   ```

4. **Existing `after_create_account` stays** (accepts the invitation). The autologin happens automatically after `after_create_account` finishes.

**Why keep verify_account enabled?** The feature remains wired up so that:
- Any pre-existing unverified accounts (from before this change) can still complete verification via email link.
- The `verify_account_view` override we keep in place still auto-verifies + auto-logs-in if someone lands on a verification URL.
- Future non-invitation signup paths (admin-created users who need to set up login themselves) continue to work.

### Task 6 — Tests

#### Model spec updates

**File:** `spec/models/access_request_spec.rb`

Add cases:
- "blocks duplicate pending request for same email"
- "blocks new request when an approved one already exists"
- "allows a new request when the prior one was rejected"
- "blocks request when email already belongs to a User"

#### Action spec updates

**File:** `spec/actions/access_requests/submit_spec.rb`

Add cases:
- "returns Failure when a pending request exists for the same email"
- "returns Failure when a User exists with the same email"

#### Request spec updates

**File:** `spec/requests/access_requests_spec.rb`

Add a case for POST `/request-access` with a duplicate email — expect unprocessable_content + flash.

#### Rodauth system specs

**File:** `spec/system/welcome_spec.rb`

- Remove the `have_content("Sign in")` expectation from the visitor test (sidebar still has it, but the panel is gone — update to only assert the "Request an invitation" card).
- Add: `expect(page).not_to have_selector(".ha-card", text: "Returning?")`

**File:** `spec/system/onboarding_redirects_spec.rb` (new)

Two flow tests:
1. Visitor submits unknown email on `/login` → lands on `/` with flash "Invitation required".
2. Visitor GETs `/create-account` without token and submits → lands on `/` with same flash.

**File:** `spec/system/invitations_spec.rb` (extend existing)

Add a case covering the full invited-signup auto-login flow:
- Create invitation for `new@example.com`
- Visit `/create-account?invitation_token=<token>`
- Submit form with the pre-filled email
- Expect: redirected to `/`, logged-in state visible (sidebar shows "Sign out"), **no** verify-account email in MailCatcher, account row has `status = 2`.

---

## 6. Files to Create

| File | Purpose |
|------|---------|
| `db/migrate/<timestamp>_add_unique_index_on_active_access_request_email.rb` | Partial unique index on `(email)` where `status IN (pending, approved)` |
| `spec/system/onboarding_redirects_spec.rb` | System coverage for Tasks 2 + 3 |

## 7. Files to Modify

| File | Change |
|------|--------|
| `app/views/welcome/home.rb` | Remove `render_signin_card`, single-column centred layout |
| `app/misc/rodauth_main.rb` | Add `before_login_attempt` (Task 2), change `validate_invitation_token` redirect (Task 3), override `account_initial_status_value`, `create_verify_account_key`, `send_verify_account_email`, set `create_account_autologin?` and `create_account_redirect` (Task 5) |
| `app/models/access_request.rb` | Add `email_not_already_active` + `email_not_already_registered` validations (Task 4) |
| `app/actions/access_requests/submit.rb` | Rescue `RecordNotUnique` race (Task 4) |
| `spec/models/access_request_spec.rb` | Duplicate/User checks |
| `spec/actions/access_requests/submit_spec.rb` | Duplicate/User checks |
| `spec/requests/access_requests_spec.rb` | Duplicate POST handling |
| `spec/system/welcome_spec.rb` | Drop Sign-in panel assertion |
| `spec/system/invitations_spec.rb` | Add auto-login-on-signup flow |

---

## 8. Key Design Decisions

1. **Consistent flash copy, "Invitation required. Request access below."** — same exact message on both the unknown-login redirect and the missing-token redirect. When the user lands on `/`, they see the single access card, which *is* the "below" the flash refers to.

2. **Partial unique index, not full unique index.** Rejected requests can legitimately be re-submitted later (the user may have been rejected in error, or circumstances changed). A full unique index on `email` would lock that out permanently. The partial index `WHERE status IN (0, 1)` matches our business rule exactly.

3. **Model validation + DB index, both.** Validations give friendly form errors; the partial unique index closes the concurrent-submit race and prevents data corruption if a future code path bypasses the validation.

4. **Keep `verify_account` feature enabled.** Removing it entirely would break the existing `verify_account_view` fast-path (which auto-verifies users who click legacy email links) and would remove our fallback for admin-created users. The right move is to *skip* it for invited signups, not remove it globally.

5. **`param_or_nil("invitation_token").present?` as the signal.** We already use this string in `before_create_account`, `after_create_account`, and the hidden-field view helper. Reusing the same predicate in three new overrides keeps the condition coherent; the token's presence is the contract that says "this is an invited signup."

6. **Homepage layout: single centred card, not a full-width banner.** Preserves the visual weight and rhythm of the current design; a full-width card would feel heavy and out-of-style with the rest of the dashboard. `mx-auto max-w-md` matches the form's visual width on `/request-access`.

7. **No re-messaging of the sidebar.** Keeping "Sign in" and "Create account" nav items for logged-out visitors is deliberate: users *can* still sign in if they already have an account, and anyone clicking "Create account" without a token now lands on `/` with the clear "Invitation required" flash — no dead end.

8. **Retroactive migration of existing unverified accounts is out of scope.** Any seeded or pre-existing unverified account is still verifiable via the old email-link path (unchanged). A follow-up data migration can bump them to status=2 if/when needed.

---

## 9. Risks

1. **`before_login_attempt` firing for paths we don't expect.** This hook runs only on POST `/login` (or its Rodauth equivalent). If a future feature adds a different POST endpoint that also does login, the hook needs review. **Mitigation:** the hook is scoped to checking `_account_from_login` for the submitted email — it's a narrow, idempotent check.

2. **Turbo + redirect interaction.** The login and create-account forms already use `data: { turbo: false }`, so `redirect "/"` from Rodauth works correctly. **Mitigation:** verified in Phase 2 runtime test; no change to Turbo behaviour in this phase.

3. **Autologin without a verification step.** Someone who steals an invitation link could immediately log in as that email. This was already the case before this phase (they'd just have needed one extra click on the verification email). We've added no new risk — the invitation token itself is the security boundary, and we already validate `invitation.email == account[login_column]` in `validate_invitation_token`. **Mitigation:** invitation expiry (already in `Invitation#expired?`) and single-use (accepted marks it accepted) remain the primary defences. No change needed.

4. **Partial unique index on SQLite.** SQLite supports partial indexes since 3.8.0 and is the only DB we target. The syntax `WHERE status IN (0, 1)` works identically to PostgreSQL's. **Mitigation:** project already has several partial unique indexes (e.g. `idx_journal_entries_telegram_idempotency`, `idx_comments_telegram_idempotency`) — the pattern is proven in this codebase.

5. **Existing tests will break.** `spec/system/welcome_spec.rb` currently asserts the "Sign in" content on the home page. That assertion is now wrong — it's part of the fix, but the spec run will fail until updated. **Mitigation:** Task 6 explicitly includes the spec update.

6. **The `no_matching_login_message` flash no longer reaches the user.** Because we redirect before Rodauth sets it, custom callers that rely on that exact string (e.g. a future API path) won't see it. **Mitigation:** the hook short-circuits only on blank-login-value bypass and on truly missing accounts; Rodauth's own error flash still fires on any other login failure mode we don't touch.

---

## 10. Verification

### Pre-commit (local)

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```

### Runtime Verification (per `/product-review` skill)

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Then with `agent-browser` at `https://catalyst.workeverywhere.docker/`:

**Homepage (logged out)**
- [ ] Single "Request an invitation" card is visible, centred
- [ ] "Returning? / Sign in" card is gone
- [ ] Sidebar still shows Sign in + Create account nav items

**Login redirect**
- [ ] Visiting `/login` and submitting `ghost@example.com` (unknown) redirects to `/`
- [ ] Flash reads "Invitation required. Request access below."
- [ ] The single access card is visible under the flash

**Create-account redirect**
- [ ] Visiting `/create-account` (no token) and submitting `anyone@example.com` redirects to `/`
- [ ] Same flash as above

**Duplicate access request**
- [ ] Submit `dupe@example.com` on `/request-access` → success flash
- [ ] Submit `dupe@example.com` again → form re-renders with error: "email already has a pending request or approved invitation"
- [ ] Seed an existing user; submit their email → form re-renders with "email is already registered — please sign in"

**Invited signup auto-login**
- [ ] Seed admin, send invitation to `new-invitee@example.com`
- [ ] Open `/create-account?invitation_token=<token>`, submit
- [ ] Browser lands on `/`, sidebar shows "Sign out" (logged in)
- [ ] MailCatcher contains **only** the signup-notification email to admins — no "Verify Account" email to the invitee
- [ ] DB query: `User.find_by(email: "new-invitee@example.com").status == 2`
- [ ] `Invitation.find_by(token: <token>).accepted?` is true

### Security Gates (per `/security-review` skill)

```bash
mise x -- bundle exec brakeman --no-pager
mise x -- bundle exec bundle-audit check --update
```

### GitHub Workflow (per `/github-workflow` skill)

1. Create issue on [Trip Issues](https://github.com/joel/trip/issues) titled "Phase 16: Onboarding Improvements" with link to this plan.
2. Add labels: `feature`, `fix`, `cleanup`.
3. Move issue through Backlog → Ready → In Progress.
4. Branch: `feature/phase16-onboarding-improvements`.
5. One PR covering all five items (they share the same onboarding surface and are best reviewed together).
6. Move to In Review on PR open; respond to all review comments; resolve conversations; merge.

---

## 11. Task Order (one PR, atomic commits per task)

1. **Commit 1** — Remove Sign-in card from homepage (Task 1 + welcome spec update)
2. **Commit 2** — Redirect to `/` on unknown login (Task 2 + new `onboarding_redirects_spec.rb` covering login side)
3. **Commit 3** — Redirect to `/` on missing/invalid invitation token (Task 3 + extend the same spec)
4. **Commit 4** — Prevent duplicate/registered-email access requests (Task 4: migration + model + action + model spec + action spec + request spec)
5. **Commit 5** — Auto-verify and auto-login invited signups (Task 5 + invitations system spec extension)

Each commit is independently reversible and passes the full test suite. No `SKIP=` hooks needed; no `[skip ci]` (all commits touch runtime code).

---

## 12. Quality Checklist

- [x] All five user-reported issues mapped to a concrete task
- [x] All new code paths have a matching spec
- [x] Validation gates are executable by project skills
- [x] References existing Rodauth and Phlex patterns
- [x] Clear commit ordering, each commit independently valid
- [x] Risks identified and mitigated
- [x] No changes to public API, MCP surface, or schema shape of any existing table
- [x] Backwards-compatible: legacy unverified accounts still verifiable via the old flow
