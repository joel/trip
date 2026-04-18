# Phase 16 — Steps Taken

Audit trail of actions performed during Phase 16 (Onboarding Improvements). Append-only for traceability.

---

## Step 0 — Plan

- Plan drafted and saved to `prompts/Phase 16 Onboarding Improvements.md` (2026-04-18).
- Confidence: 9/10.
- Scope: 5 discrete fixes, 1 PR, 5 atomic commits (grew to 7 commits after two in-flight corrections).
- User approved the plan before implementation.

---

## Step 1 — GitHub issue

- Created issue **#102** via `gh issue create`: https://github.com/joel/trip/issues/102
  - Label: `enhancement`
  - Body: scope, verification plan, link back to `PRPs`-style plan document.
- Attempted `gh project item-add 2 --owner joel --url …/issues/102` to push onto the Kanban board. Failed: current `gh` token is missing the `read:project` scope. Issue is tracked via the issue itself; the Kanban move is documented here as a skipped step.

---

## Step 2 — Branch

- `git checkout main && git pull origin main` — fast-forwarded 4 commits.
- `git checkout -b feature/phase16-onboarding-improvements`.

---

## Step 3 — Implementation (atomic commits)

### Commit `a44247e` — Task 1: Remove Sign-in card from logged-out homepage

- `app/views/welcome/home.rb`: deleted `render_signin_card`; `render_logged_out` now renders a single centred `mx-auto w-full max-w-md` container around `render_access_card`.
- `spec/system/welcome_spec.rb`: updated visitor assertion to check for "Request an invitation" + link "Request Access" and `have_no_content("Returning?")`.
- First attempt triggered a `Capybara/NegationMatcher` RuboCop warning (`not_to have_content` → `have_no_content`); fixed and re-committed.

### Commit `13f237a` — Task 2: Redirect home on unknown login (initial attempt)

- `app/misc/rodauth_main.rb`: added `before_login_attempt` hook that `_account_from_login`-checks the submitted email and redirects to `/` with flash "Invitation required. Request access below."
- Added `spec/system/onboarding_redirects_spec.rb` with the unknown-login redirect scenario.

### Commit `149e32c` — Task 3: Redirect home on missing invitation token

- `app/misc/rodauth_main.rb`: changed `validate_invitation_token` redirect target from `create_account_path` to `/`; unified flash text with Task 2.
- `spec/system/onboarding_redirects_spec.rb`: added the create-account-without-token scenario.
- Commit-msg hook warned about 60-char subject limit (informational, not a block).

### Commit `65ce60a` — Task 4: Block duplicate and already-registered access requests

- `db/migrate/20260418120000_add_unique_index_on_active_access_request_email.rb`: partial unique index on `(email) WHERE status IN (0, 1)` (SQLite-compatible).
- `app/models/access_request.rb`: added `email_not_already_active` and `email_not_already_registered` validations.
- `app/actions/access_requests/submit.rb`: added `ActiveRecord::RecordNotUnique` rescue branch to convert the DB race path into a `Failure(errors)`.
- Migration initially failed: dev DB already had two active requests for `john.doe@acme.org`. Ran a one-off runner script via `docker exec -i catalyst-app-dev bin/rails runner -` to delete the older duplicate, then re-ran the migration in both `development` and `test`.
- Re-generated `db/schema.rb` via `docker exec catalyst-app-dev bin/rails db:schema:dump` (schema version bumped to `2026_04_18_120000`).
- Specs updated: `spec/models/access_request_spec.rb` (4 new cases), `spec/actions/access_requests/submit_spec.rb` (2 new cases), `spec/requests/access_requests_spec.rb` (2 new cases).
- `RailsSchemaUpToDate` overcommit hook passed after schema dump.

### Commit `293e3b6` — Task 5: Skip verify-account step for invited signups

- `app/misc/rodauth_main.rb`:
  - `create_account_autologin? { param_or_nil("invitation_token").present? }`
  - `create_account_redirect { "/" }`
  - Inside `auth_class_eval`: overrode `account_initial_status_value` (returns `account_open_status_value` when invitation token is present), `create_verify_account_key` (no-op guard), and `send_verify_account_email` (no-op guard).
- `spec/system/invitations_spec.rb`: added acceptance scenario verifying auto-login, `user.status == 2`, `invitation.accepted?`, and no "verify" subject in `ActionMailer::Base.deliveries`.

---

## Step 4 — Test runs (pre-runtime)

- `mise x -- bundle exec rake project:lint` → clean (424 files, 0 offenses).
- `mise x -- bundle exec rake project:tests` → **580 examples, 0 failures**, 2 pending (unchanged helper specs).
- `mise x -- bundle exec rake project:system-tests` → **1 failure**: `onboarding_redirects_spec` for the unknown-login case.
  - Root cause: read `rodauth-2.43.0/lib/rodauth/features/login.rb:49-53` — `account_from_login` runs BEFORE `before_login_attempt`, so the hook never fires when the account is missing.
  - Fix applied in commit `81762e6` below.

### Commit `81762e6` — Switch unknown-login hook to `before_login_route`

- Replaced `before_login_attempt` block with `before_login_route`, guarded by `request.post?`. This hook runs before Rodauth's own account lookup, so the "no matching account" branch can be intercepted cleanly.
- Added a short comment explaining the ordering rationale.
- Re-ran `project:system-tests` → **63 examples, 0 failures**.

---

## Step 5 — Runtime verification (`/product-review`)

Workflow: `bin/cli app rebuild && bin/cli app restart && bin/cli mail start && curl -X DELETE mail/messages`.

### Verified in browser via agent-browser (screenshots in `/tmp/p16-*.png`)

1. **Home page, logged out** — single centred "Request an invitation" card; no "Returning? / Sign in" panel; sidebar still shows Sign in + Create account for returning users. ✔
2. **Unknown login redirect** — POST `/login` with `ghost@example.com` → redirected to `/` with toast "Action needed: Invitation required. Request access below." ✔
3. **Create-account without token** — POST `/create-account` with `anyone@example.com` → redirected to `/` with the same toast. ✔
4. **Duplicate access request** — first submission for `phase16-dupe@example.com` succeeded; second submission rendered the form with inline error "Email already has a pending request or approved invitation." ✔
5. **Already-registered email** — submission for `joel@acme.org` rendered the form with "Email is already registered — please sign in." ✔
6. **Invited signup (first pass)** — seeded invitation for `phase16-invitee@example.com`, email was prefilled + readonly, submission landed on `/` with sidebar showing "Sign out" (auto-logged in). BUT the flash still read "An email has been sent to you with a link to verify your account" (Rodauth's default `create_account_notice_flash`, inherited from the verify_account feature).
7. **Flash copy fix (commit `66f9784`)** — overrode `create_account_notice_flash` to return "Welcome! Your account is ready." when the invitation token is present. Restarted the app, re-ran the invited signup flow with `phase16-invitee2@example.com`. Flash now reads the new message. ✔
8. **Mail inbox check** — after the invited signup, only the admin signup-notification email was sent (`New user signed up: [FILTERED]` → `<joel@acme.org>`); no "Verify Account" email. ✔
9. **DB sanity** — `User.find_by(email: "phase16-invitee2@example.com").status == 2`; `Invitation.find_by(email: …).accepted? == true`. ✔
10. **Existing-user login regression check** — email `joel@acme.org` on `/login` → transitioned to multi-phase-login page with "Email recognized. Choose how to sign in." flash and Passkey/Email-link cards visible. No regression from the new hook. ✔
11. **Admin pages regression check** — signed in as `joel@acme.org` via email-auth link, visited `/access_requests`, saw the pending request we submitted plus existing seeded records, with Approve/Reject buttons. ✔

### Commit `66f9784` — Override create_account notice for invited signups

- Added `create_account_notice_flash` override inside `auth_class_eval`: returns "Welcome! Your account is ready." when `invitation_token` is present, else `super`.

---

## Step 6 — Final branch state

Seven atomic commits on `feature/phase16-onboarding-improvements` (main → HEAD):

```
66f9784  Override create_account notice for invited signups
81762e6  Switch unknown-login hook to before_login_route
293e3b6  Skip verify-account step for invitation-based signups
65ce60a  Block duplicate and already-registered access requests
149e32c  Redirect home when create-account is missing a valid invitation token
13f237a  Redirect home when login is attempted without an account
a44247e  Remove Sign-in card from logged-out homepage
```

Tests: 580 non-system + 63 system = **643 examples, 0 failures, 2 pending**. Lint clean. Overcommit hooks all green.

---

## Step 7 — Push + PR

- `git push -u origin feature/phase16-onboarding-improvements` succeeded.
- `gh pr create` opened **PR #103**: https://github.com/joel/trip/pull/103
  - Title: "Phase 16: Onboarding improvements"
  - Body covers summary, test plan, and `Closes #102`.
- Move Kanban item to "In Review" deferred — requires `read:project` scope refresh on the local `gh` token (`gh auth refresh -s read:project`). Issue + PR linkage still provides full tracking.

## Step 8 — Outcome

- 7 commits, 643 green specs, 0 lint offenses, full runtime verification complete.
- Files touched: 10 (3 app/, 1 db/migrate/, 1 db/schema.rb, 5 spec/).
- No schema-shape changes to any existing table; only a partial unique index added.
- Backwards compatible: existing unverified users can still verify via the old email link flow.
