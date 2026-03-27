# Phase 15: Social Login with Google via rodauth-omniauth

**Status:** Draft
**Date:** 2026-03-27
**Confidence Score:** 8/10 (well-documented gem, clear integration path, passwordless architecture simplifies things)

---

## 1. Context

The app uses **Rodauth** for authentication with a fully passwordless flow:
- **Email auth** (magic links)
- **WebAuthn** (passkeys)
- **Invitation-gated** account creation

Users must receive an invitation to create an account. There are no passwords. This phase adds **Google Sign-In** as a third authentication method, allowing invited users to sign in faster and new users (when approved) to use their Google identity.

**Key decision:** Google login should **not** bypass the invitation requirement for new accounts. If a Google user's email doesn't match an existing account, they should be shown a message explaining that an invitation is required.

---

## 2. Reference Documentation

| Resource | URL |
|----------|-----|
| rodauth-omniauth gem | https://github.com/janko/rodauth-omniauth |
| rodauth-rails OmniAuth wiki | https://github.com/janko/rodauth-rails/wiki/OmniAuth |
| omniauth-google-oauth2 gem | https://github.com/zquestz/omniauth-google-oauth2 |
| AppSignal guide | https://blog.appsignal.com/2023/04/05/how-to-use-the-rodauth-omniauth-gem-in-ruby.html |
| Author's blog post | https://janko.io/social-login-in-rails-with-rodauth/ |
| Rodauth demo app | https://github.com/janko/rodauth-demo-rails |
| Google Cloud Console | https://console.cloud.google.com |

---

## 3. Scope

### What This Phase Adds

1. **Google Sign-In button** on the login page and create-account page
2. **`account_identities` table** to store Google provider + UID per user
3. **rodauth-omniauth configuration** in `RodauthMain`
4. **Automatic account linking** when Google email matches an existing user
5. **Auto-verification** of accounts when authenticated via Google
6. **Name population** from Google profile when creating new accounts
7. **Environment variables** for Google OAuth credentials

### What This Phase Does NOT Add

- Account creation without invitation (Google login still requires a pre-existing account or invitation)
- Other OAuth providers (GitHub, Facebook, etc.) -- deferred
- Account unlinking UI (remove Google identity)
- Profile picture sync from Google

---

## 4. Existing Codebase Context

### Rodauth Configuration (`app/misc/rodauth_main.rb`)

The current Rodauth setup enables: `:create_account`, `:verify_account`, `:login`, `:logout`, `:email_auth`, `:webauthn`, `:webauthn_login`.

Key settings:
```ruby
accounts_table :users
account_status_column :status
login_param "email"
create_account_set_password? false
require_bcrypt? false
```

Passwords are completely disabled. The `before_create_account` hook validates invitation tokens and generates UUIDs. The `after_create_account` hook marks invitations as accepted.

### User Model (`app/models/user.rb`)

UUID primary keys. Email is required, unique, case-insensitive. Status column: 1 = unverified, 2 = verified. Roles via `roles_mask` bitmask. No password digest field.

### Login Views (Phlex)

All auth views are custom Phlex components in `app/views/rodauth/`:
- `login.rb` -- Email entry with brand header
- `multi_phase_login.rb` -- Choose passkey or email link
- `create_account.rb` -- Invitation-gated signup form

### Database

SQLite with UUID primary keys. All Rodauth tables use `user_` prefix:
- `user_email_auth_keys`
- `user_verification_keys`
- `user_webauthn_keys`
- `user_webauthn_user_ids`

---

## 5. Implementation Plan

### Task 1: Add gems

Add to `Gemfile`:
```ruby
# Social login (OAuth)
gem "rodauth-omniauth"
gem "omniauth-google-oauth2"
```

Run `bundle install`.

**Note:** rodauth-omniauth includes OmniAuth 2.x and handles CSRF protection automatically via Rodauth. No need for `omniauth-rails_csrf_protection`.

### Task 2: Create `account_identities` migration

Follow the project convention: UUID PKs, `user_` prefix is NOT needed here (rodauth-omniauth uses `account_identities` by default, and the gem maps to the correct table).

```ruby
class CreateAccountIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :account_identities, id: :uuid do |t|
      t.references :user, type: :uuid, null: false,
                          foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps
    end

    add_index :account_identities, %i[provider uid], unique: true
  end
end
```

**Important:** The gem defaults to `account_id` column. Since our accounts table is `users`, we need to configure `omniauth_identities_account_id_column :user_id` in Rodauth config. The table name `account_identities` is the gem default -- but if we want to follow the project's `user_` prefix convention, use `omniauth_identities_table :user_omniauth_identities`. Decision: use the gem default `account_identities` to minimize configuration.

Actually, looking at the codebase pattern more carefully, all auth tables use `user_` prefix. So:

```ruby
create_table :user_omniauth_identities, id: :uuid do |t|
  t.references :user, type: :uuid, null: false,
                       foreign_key: { on_delete: :cascade }
  t.string :provider, null: false
  t.string :uid, null: false
  t.timestamps
end
```

And configure: `omniauth_identities_table :user_omniauth_identities` + `omniauth_identities_account_id_column :user_id`.

### Task 3: Configure rodauth-omniauth in `RodauthMain`

Add `:omniauth` to the enabled features and configure the Google provider:

```ruby
enable :create_account, :verify_account, :login, :logout,
       :email_auth, :webauthn, :webauthn_login, :omniauth

omniauth_provider :google_oauth2,
                  ENV["GOOGLE_CLIENT_ID"],
                  ENV["GOOGLE_CLIENT_SECRET"],
                  name: :google,
                  scope: "email,profile"

# Table configuration
omniauth_identities_table :user_omniauth_identities
omniauth_identities_account_id_column :user_id

# Do NOT auto-create accounts -- require invitation
omniauth_create_account? false

# Auto-verify accounts authenticated via Google
omniauth_verify_account? true
```

**Key decision:** `omniauth_create_account? false` ensures Google login cannot bypass the invitation system. Users must already have an account (created via invitation flow) to sign in with Google. If no account exists, rodauth-omniauth will show an error.

### Task 4: Populate name from Google profile

When an existing account links with Google for the first time, populate the name if blank:

```ruby
# In RodauthMain auth_class_eval block
after_omniauth_setup do
  return unless account && omniauth_name.present?

  user = ::User.find_by(id: account_id)
  user&.update!(name: omniauth_name) if user && user.name.blank?
end
```

### Task 5: Add Google Sign-In button to login page

Modify `app/views/rodauth/login.rb` to add a Google button below the email form:

```ruby
def render_login_panel
  div(class: "ha-glass rounded-[2rem] p-8 shadow-[var(--ha-card-shadow)]") do
    # ... existing email form ...

    render_social_divider
    render_google_button
  end
end

def render_social_divider
  div(class: "relative mt-6 mb-6") do
    div(class: "absolute inset-0 flex items-center") do
      div(class: "w-full border-t border-[var(--ha-border)]/30")
    end
    div(class: "relative flex justify-center text-xs") do
      span(class: "bg-white dark:bg-[var(--ha-surface)] px-4 " \
                  "text-[var(--ha-muted)]") do
        plain "or continue with"
      end
    end
  end
end

def render_google_button
  button_to(
    view_context.rodauth.omniauth_request_path(:google),
    method: :post,
    data: { turbo: false },
    class: "w-full flex items-center justify-center gap-3 " \
           "ha-button ha-button-secondary"
  ) do
    render_google_icon
    span { "Sign in with Google" }
  end
end
```

### Task 6: Add Google SVG icon component

Create `app/components/icons/google.rb` with the official Google "G" logo SVG (multi-color, 20x20 viewBox).

### Task 7: Add environment variables

Add to `.env.development`:
```
GOOGLE_CLIENT_ID=your-client-id-here
GOOGLE_CLIENT_SECRET=your-client-secret-here
```

Document in `CLAUDE.md` or a setup guide that developers need to:
1. Go to Google Cloud Console
2. Create OAuth 2.0 credentials
3. Add callback URL: `https://catalyst.workeverywhere.docker/auth/google/callback`

### Task 8: Add Google button to multi-phase login page

Modify `app/views/rodauth/multi_phase_login.rb` to show Google as a third option in the grid (alongside Passkey and Email Link).

### Task 9: Tests

**Model spec:** `spec/models/user_spec.rb` -- verify account identities association/cascade
**Request spec:** `spec/requests/omniauth_spec.rb` -- test Google callback with mocked auth hash
**System spec:** `spec/system/social_login_spec.rb` -- verify Google button visible on login page

For testing OmniAuth in RSpec:
```ruby
# spec/support/omniauth.rb
OmniAuth.config.test_mode = true
OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
  provider: "google_oauth2",
  uid: "123456",
  info: {
    email: "joel@acme.org",
    name: "Joel Azemar"
  }
)
```

### Task 10: Handle error case (no account found)

When `omniauth_create_account? false` and no matching account exists, rodauth-omniauth shows a generic error. Customize:

```ruby
omniauth_login_failure_redirect { login_path }
set_omniauth_error_flash do
  "No account found for this Google email. An invitation is required to create an account."
end
```

---

## 6. Files to Create (~6)

| File | Purpose |
|------|---------|
| `db/migrate/YYYYMMDD_create_user_omniauth_identities.rb` | Identities table |
| `app/components/icons/google.rb` | Google "G" icon SVG |
| `spec/support/omniauth.rb` | OmniAuth test mode + mock |
| `spec/requests/omniauth_spec.rb` | Callback tests |
| `spec/system/social_login_spec.rb` | Button visibility test |

## 7. Files to Modify (~5)

| File | Change |
|------|--------|
| `Gemfile` | Add `rodauth-omniauth` + `omniauth-google-oauth2` |
| `app/misc/rodauth_main.rb` | Enable `:omniauth`, configure Google provider, table names |
| `app/views/rodauth/login.rb` | Add Google button + divider |
| `app/views/rodauth/multi_phase_login.rb` | Add Google option |
| `.env.development` | Add `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` |

---

## 8. Key Design Decisions

1. **No auto-account-creation** (`omniauth_create_account? false`) -- invitation system remains the gatekeeper. Google login is a convenience for existing users, not an open registration channel.

2. **Auto-verify on Google login** (`omniauth_verify_account? true`) -- if an unverified user signs in with Google, they're auto-verified. This is safe because Google has already verified the email.

3. **Auto-link by email** -- rodauth-omniauth automatically matches Google email to existing accounts. If user@acme.org exists and signs in with Google using the same email, the identity is linked.

4. **Name backfill** -- on first Google login, if the user's name is blank, populate it from the Google profile. Don't overwrite existing names.

5. **`user_omniauth_identities` table name** -- follows the `user_*` prefix convention for all auth-related tables in this project.

---

## 9. Risks

1. **Docker callback URL** -- The OAuth callback must use the Docker hostname (`catalyst.workeverywhere.docker`). Google OAuth requires HTTPS. The Docker setup uses a self-signed cert. Google may reject callbacks if the cert is untrusted. **Mitigation:** Use `localhost` callback for development, or configure Google to accept the Docker hostname.

2. **Missing env vars** -- If `GOOGLE_CLIENT_ID` or `GOOGLE_CLIENT_SECRET` are not set, the OmniAuth provider will fail at boot. **Mitigation:** Guard with `ENV.fetch("GOOGLE_CLIENT_ID", nil)` and only configure the provider if present.

3. **Sequel + OmniAuth middleware** -- rodauth-omniauth patches into Rodauth's Roda middleware layer. There may be interaction with the existing Sequel/ActiveRecord bridge. **Mitigation:** Test thoroughly in Docker.

4. **Turbo incompatibility** -- OmniAuth POST requests redirect to Google (302 to external domain). Turbo will follow this and break. **Mitigation:** Use `data: { turbo: false }` on all OmniAuth buttons (already documented in rodauth-omniauth).

---

## 10. Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Verification
- [ ] Login page shows "Sign in with Google" button
- [ ] Multi-phase login shows Google as third option
- [ ] Clicking Google button redirects to Google consent screen
- [ ] Returning from Google logs in the user (if account exists)
- [ ] User name populated from Google profile (if blank)
- [ ] No-account case shows appropriate error message
- [ ] `user_omniauth_identities` record created after first Google login
- [ ] Existing passkey and email auth still work unchanged
- [ ] Create account page still requires invitation (Google doesn't bypass)
- [ ] All existing tests pass

### Definition of Done
- [ ] `rodauth-omniauth` + `omniauth-google-oauth2` in Gemfile.lock
- [ ] `user_omniauth_identities` table created
- [ ] Google provider configured in RodauthMain
- [ ] Google button on login + multi-phase login pages
- [ ] Error message for non-existent accounts
- [ ] Name backfill from Google profile
- [ ] Tests pass, lint clean
- [ ] Runtime verification in Docker
