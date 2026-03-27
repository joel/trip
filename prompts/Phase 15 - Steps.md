# Phase 15: Google Social Login — Steps Taken

**Date:** 2026-03-27
**Issue:** joel/trip#52
**Branch:** `feature/phase-15-google-social-login`

---

## Commits

### 1. Add rodauth-omniauth and omniauth-google-oauth2 gems
- Added `omniauth-google-oauth2` and `rodauth-omniauth` to Gemfile
- No `omniauth-rails_csrf_protection` needed (handled by Rodauth)

### 2. Add user_omniauth_identities table for social login
- Created `db/migrate/20260327200001_create_user_omniauth_identities.rb`
- UUID PK, user_id FK with cascade delete, provider + uid with unique index
- Follows `user_*` prefix convention for auth tables

### 3. Configure rodauth-omniauth with Google provider
- Enabled `:omniauth` feature in `app/misc/rodauth_main.rb`
- Configured `omniauth_identities_table :user_omniauth_identities`
- Configured `omniauth_identities_account_id_column :user_id`
- Added Google OAuth2 provider guarded by `ENV["GOOGLE_CLIENT_ID"].present?`
- Set `omniauth_create_account? false` to preserve invitation gating
- Set `omniauth_verify_account? true` for auto-verification
- Added `before_omniauth_callback_route` hook for name backfill
- Added `omniauth_login_failure_redirect` for error handling

### 4. Add Google Sign-In button to login and multi-phase pages
- Created `app/components/icons/google.rb` — multi-color Google "G" SVG
- Modified `app/views/rodauth/login.rb` — added divider ("or continue with") + Google button
- Modified `app/views/rodauth/multi_phase_login.rb` — added Google as third auth option in a card
- Both buttons use `data: { turbo: false }` for external OAuth redirect
- Google section only renders when `GOOGLE_CLIENT_ID` is set

### 5. Add system spec for social login button visibility
- Created `spec/system/social_login_spec.rb`
- Tests that Google button is hidden when env var not set

---

## Test Results

- **Unit + request specs:** 521 examples, 0 failures
- **System tests:** 23 examples, 0 failures
- **Lint:** 405 files inspected, no offenses

---

## Files Created (3)

| File | Purpose |
|------|---------|
| `db/migrate/20260327200001_create_user_omniauth_identities.rb` | Identities table |
| `app/components/icons/google.rb` | Google "G" icon SVG |
| `spec/system/social_login_spec.rb` | Button visibility spec |

## Files Modified (3)

| File | Change |
|------|--------|
| `Gemfile` | Added `rodauth-omniauth` + `omniauth-google-oauth2` |
| `app/misc/rodauth_main.rb` | Enabled `:omniauth`, Google provider, table config, hooks |
| `app/views/rodauth/login.rb` | Google button + divider |
| `app/views/rodauth/multi_phase_login.rb` | Google as third auth option |

---

## Configuration Required

To enable Google Sign-In, set these environment variables:

```
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
```

Get credentials at https://console.cloud.google.com:
1. Create or select a project
2. APIs & Services > Credentials > Create Credentials > OAuth 2.0 Client ID
3. Application type: Web application
4. Authorized redirect URIs: `https://catalyst.workeverywhere.docker/auth/google/callback`

Without these env vars, the Google button is hidden and the app works as before.
