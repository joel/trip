# PRP: Google One Tap Auto Sign-In

**Status:** Draft
**Date:** 2026-04-01
**Type:** Feature
**Confidence Score:** 8/10 (well-scoped, clear patterns to follow, main risk is Rodauth session management outside OmniAuth flow)

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Codebase Context](#2-codebase-context)
3. [Technical Approach](#3-technical-approach)
4. [Implementation Tasks](#4-implementation-tasks)
5. [Validation Gates](#5-validation-gates)
6. [Reference Documentation](#6-reference-documentation)

---

## 1. Problem Statement

### Current State

Users who are already signed into Google in their browser must manually navigate to `/login` and click "Sign in with Google" to authenticate via the OmniAuth redirect flow. This is friction-heavy for returning users who have already linked their Google identity to their account.

### Desired State

When a logged-out user visits any page (home, login), if they have an active Google session in their browser and have previously approved the app (or are willing to approve), they should see a **Google One Tap** prompt that allows them to sign in with a single click — or even automatically if they are a returning user (`auto_select: true`).

### Key Behaviors

1. **Returning users with linked Google identity**: Auto-sign-in (no click required) via `auto_select: true`
2. **Users with active Google session but no linked identity**: Show One Tap prompt; if their email matches an existing account, link identity and log in
3. **Users with active Google session but no account**: Show One Tap prompt; on credential response, inform them an invitation is required (since `omniauth_create_account?` is `false`)
4. **Users without Google session**: One Tap doesn't appear; existing auth flows unchanged
5. **Existing Google OAuth button**: Continues to work as-is on login/multi-phase-login pages

### Non-Goals

- Account creation via One Tap (invitation system remains enforced)
- Replacing the existing OmniAuth redirect flow
- Google One Tap on authenticated pages

---

## 2. Codebase Context

### Authentication Architecture

| Area | Technology | Key File |
|------|-----------|----------|
| Auth framework | Rodauth (via rodauth-rails) | `app/misc/rodauth_main.rb` |
| Social login | OmniAuth + rodauth-omniauth | `app/misc/rodauth_main.rb:27-44` |
| Google OAuth gem | `omniauth-google-oauth2` | `Gemfile:35` |
| Identity storage | `user_omniauth_identities` table | `db/schema.rb:220-226` |
| Session persistence | Rodauth `:remember` feature (30 days) | `app/misc/rodauth_main.rb:20-25` |
| Views | Phlex components | `app/views/rodauth/login.rb` |
| JS framework | Stimulus + Importmap | `config/importmap.rb` |
| CSS | Tailwind with custom design tokens | `app/assets/tailwind/application.css` |

### Current Google OAuth Flow

1. User clicks "Sign in with Google" button (`app/views/rodauth/login.rb:80-91`)
2. `button_to` POSTs to `rodauth.omniauth_request_path(:google)` with `data: { turbo: false }`
3. OmniAuth middleware redirects to Google
4. Google redirects back to callback URL
5. `rodauth-omniauth` processes callback: finds/creates identity, logs in user
6. `after_login` hook (`rodauth_main.rb:140-149`) calls `remember_login` and backfills name

### Key Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `app/javascript/controllers/google_one_tap_controller.js` | **CREATE** | Stimulus controller: loads GIS library, initializes One Tap, handles credential callback |
| `app/controllers/google_one_tap_sessions_controller.rb` | **CREATE** | Backend: verifies JWT, finds/links identity, creates Rodauth session |
| `app/components/google_one_tap.rb` | **CREATE** | Phlex component: renders Stimulus controller div with data attributes |
| `config/routes.rb` | **MODIFY** | Add `POST /auth/google/one_tap` route |
| `app/views/layouts/application_layout.rb` | **MODIFY** | Render `GoogleOneTap` component in body |
| `spec/requests/google_one_tap_sessions_spec.rb` | **CREATE** | Request specs for JWT verification and session creation |
| `spec/system/google_one_tap_spec.rb` | **CREATE** | System spec for One Tap visibility |

### Key Files to Reference (Read-Only)

| File | Why |
|------|-----|
| `app/misc/rodauth_main.rb` | Rodauth config, OmniAuth hooks, session management, remember feature |
| `app/views/rodauth/login.rb` | Existing Google button pattern, `google_configured?` helper |
| `app/views/rodauth/multi_phase_login.rb` | Second place with Google button |
| `app/controllers/test_sessions_controller.rb` | Pattern for creating Rodauth sessions programmatically |
| `app/components/icons/google.rb` | Existing Google SVG icon |
| `app/views/layouts/application_layout.rb` | Where to inject the One Tap component |
| `spec/system/social_login_spec.rb` | Existing Google button visibility test pattern |
| `spec/support/system_auth_helpers.rb` | System test auth helpers |
| `db/schema.rb:220-226` | `user_omniauth_identities` table schema |

### Existing Patterns to Follow

**Rodauth session creation (from `app/controllers/test_sessions_controller.rb`):**
```ruby
session[rodauth.session_key] = user.id
session[rodauth.authenticated_by_session_key] = ["test"]
```

**OmniAuth name backfill (from `rodauth_main.rb:140-149`):**
```ruby
after_login do
  remember_login
  next unless authenticated_by&.include?("omniauth")
  next if omniauth_name.blank?
  user = ::User.find_by(id: account_id)
  user&.update!(name: omniauth_name) if user&.name.blank?
end
```

**Google button conditional (from `app/views/rodauth/login.rb:93-95`):**
```ruby
def google_configured?
  ENV["GOOGLE_CLIENT_ID"].present?
end
```

**Identity table schema:**
```
user_omniauth_identities: id (uuid), user_id (uuid FK), provider (string), uid (string)
Unique index on [provider, uid]
```

---

## 3. Technical Approach

### Architecture Overview

```
Browser (logged-out user)
  │
  ├─ GIS library loaded by Stimulus controller
  ├─ google.accounts.id.initialize({ client_id, callback, auto_select: true })
  ├─ google.accounts.id.prompt() → shows One Tap UI (or auto-selects)
  │
  ▼ User approves (or auto-selected)
  │
  ├─ GIS returns JWT credential to Stimulus callback
  ├─ Stimulus POSTs { credential } to /auth/google/one_tap
  │
  ▼ Backend (GoogleOneTapSessionsController#create)
  │
  ├─ 1. Verify JWT with Google tokeninfo endpoint
  ├─ 2. Extract email + Google UID (sub claim)
  ├─ 3. Find identity by (provider: "google", uid: sub)
  │     ├─ Found → log in the associated user
  │     └─ Not found → find user by email
  │           ├─ Found → create identity record, log in
  │           └─ Not found → return error (invitation required)
  ├─ 4. Set Rodauth session + remember_login
  └─ 5. Return JSON { ok: true } → JS reloads page
```

### Google One Tap vs Existing OmniAuth Flow

| Aspect | Existing OmniAuth | Google One Tap |
|--------|-------------------|----------------|
| Trigger | User clicks button | Automatic prompt or auto-select |
| Flow | Full OAuth redirect | JWT returned to JS callback |
| Library | omniauth-google-oauth2 | Google Identity Services (GIS) JS |
| Backend | rodauth-omniauth callback | Custom controller + JWT verify |
| Session | Set by rodauth-omniauth | Set manually (like test controller) |

Both flows coexist. One Tap provides frictionless sign-in; the OAuth button remains for explicit sign-in.

### JWT Verification Strategy

Use Google's `tokeninfo` endpoint for simplicity (no new gem required):

```ruby
uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{credential}")
response = Net::HTTP.get_response(uri)
payload = JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
```

**Verify:**
- `payload["aud"] == ENV["GOOGLE_CLIENT_ID"]` (audience matches our app)
- `payload["email_verified"] == "true"` (email is verified by Google)
- `payload["exp"].to_i > Time.now.to_i` (token not expired)

The JWT payload contains: `sub` (Google user ID), `email`, `email_verified`, `name`, `given_name`, `family_name`, `picture`, `aud`, `iss`, `exp`, `iat`.

### Session Creation

Follow the pattern from `test_sessions_controller.rb`, plus call `remember_login`:

```ruby
def login_user(user)
  session[rodauth.session_key] = user.id
  session[rodauth.authenticated_by_session_key] = ["google_one_tap"]
  rodauth.remember_login
end
```

### Identity Linking

When a user's Google UID doesn't have an identity record but their email matches an existing account, create the link:

```ruby
ActiveRecord::Base.connection.exec_insert(
  "INSERT INTO user_omniauth_identities (id, user_id, provider, uid) VALUES (?, ?, ?, ?)",
  "SQL", [[nil, SecureRandom.uuid], [nil, user.id], [nil, "google"], [nil, google_uid]]
)
```

Use raw SQL since there's no ActiveRecord model for `user_omniauth_identities` — Rodauth manages this table via Sequel. Creating an AR model just for this insert would be unnecessary.

### FedCM Compatibility

Google is migrating to FedCM (Federated Credential Management). Enable it:

```javascript
google.accounts.id.initialize({
  client_id: clientId,
  callback: handleCredential,
  auto_select: true,
  use_fedcm_for_prompt: true  // Future-proof
})
```

### Security Considerations

1. **CSRF**: Skip `verify_authenticity_token` for the One Tap endpoint. The JWT itself proves the request came from Google via the user's browser. The `aud` claim verification prevents token misuse.
2. **Token replay**: Google JWTs expire quickly (~5 min). The `exp` check prevents replay.
3. **Account status**: Only log in users with open accounts (`status == rodauth.account_open_status_value`). Do not auto-open unverified or locked accounts.
4. **No account creation**: Respect the invitation requirement. One Tap only logs in existing accounts or links identities to existing accounts.
5. **Rate limiting**: Not in scope for this PRP, but recommend adding later.

### Edge Cases

| Case | Behavior |
|------|----------|
| User dismisses One Tap | GIS applies exponential cooldown; prompt won't show for increasing periods |
| Multiple Google accounts in browser | GIS shows account chooser instead of auto-select |
| Google email not matching any account | Return JSON error; JS shows flash "No account found. Request an invitation." |
| Account exists but is unverified/locked | Return JSON error; do not log in |
| GOOGLE_CLIENT_ID not set | Component doesn't render; no GIS script loaded |
| User already logged in | Component doesn't render |
| Turbo navigation | Stimulus `connect()`/`disconnect()` handle re-initialization |

---

## 4. Implementation Tasks

### Task 1: Create the Stimulus Controller

**File:** `app/javascript/controllers/google_one_tap_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    clientId: String,
    loginPath: String
  }

  connect() {
    this.loadScript().then(() => this.initialize())
  }

  disconnect() {
    if (window.google?.accounts?.id) {
      window.google.accounts.id.cancel()
    }
  }

  loadScript() {
    return new Promise((resolve) => {
      if (window.google?.accounts?.id) return resolve()
      const s = document.createElement("script")
      s.src = "https://accounts.google.com/gsi/client"
      s.async = true
      s.defer = true
      s.onload = resolve
      document.head.appendChild(s)
    })
  }

  initialize() {
    window.google.accounts.id.initialize({
      client_id: this.clientIdValue,
      callback: this.handleCredential.bind(this),
      auto_select: true,
      cancel_on_tap_outside: true,
      context: "signin",
      use_fedcm_for_prompt: true
    })
    window.google.accounts.id.prompt()
  }

  handleCredential(response) {
    const csrfToken = document.querySelector(
      "meta[name='csrf-token']"
    )?.content

    fetch(this.loginPathValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ credential: response.credential })
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.ok) {
          window.location.replace(data.redirect || "/")
        } else if (data.error) {
          // Could show a toast or flash message
          if (data.redirect) window.location.href = data.redirect
        }
      })
  }
}
```

**Why this approach:**
- Dynamic script loading avoids loading GIS on pages that don't need it
- `auto_select: true` enables zero-click sign-in for returning users
- `use_fedcm_for_prompt: true` future-proofs for Chrome's FedCM migration
- CSRF token read from meta tag (already rendered by `csrf_meta_tags` in layout head)
- `disconnect()` cancels the prompt on Turbo navigation

---

### Task 2: Create the Backend Controller

**File:** `app/controllers/google_one_tap_sessions_controller.rb`

```ruby
# frozen_string_literal: true

class GoogleOneTapSessionsController < ApplicationController
  skip_forgery_protection only: :create

  def create
    payload = verify_google_token(params[:credential])
    unless payload
      return render json: { error: "invalid_token" },
                    status: :unprocessable_entity
    end

    google_uid = payload["sub"]
    email = payload["email"]&.downcase

    # 1. Try existing identity
    identity = find_identity(google_uid)
    if identity
      user = User.find(identity["user_id"])
      return login_and_respond(user, google_uid, payload)
    end

    # 2. Try existing account by email
    user = User.find_by(email: email)
    if user
      create_identity(user, google_uid)
      return login_and_respond(user, google_uid, payload)
    end

    # 3. No account — invitation required
    render json: {
      error: "no_account",
      redirect: new_access_request_path
    }, status: :unprocessable_entity
  end

  private

  def verify_google_token(token)
    return nil if token.blank?

    uri = URI(
      "https://oauth2.googleapis.com/tokeninfo?id_token=#{token}"
    )
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return nil unless data["aud"] == ENV["GOOGLE_CLIENT_ID"]
    return nil unless data["email_verified"] == "true"

    data
  rescue JSON::ParserError, SocketError, Timeout::Error
    nil
  end

  def find_identity(google_uid)
    ActiveRecord::Base.connection.select_one(
      "SELECT user_id FROM user_omniauth_identities " \
      "WHERE provider = 'google' AND uid = ?",
      "GoogleOneTap",
      [google_uid]
    )
  end

  def create_identity(user, google_uid)
    ActiveRecord::Base.connection.exec_insert(
      "INSERT INTO user_omniauth_identities " \
      "(id, user_id, provider, uid) VALUES (?, ?, ?, ?)",
      "GoogleOneTap",
      [[nil, SecureRandom.uuid], [nil, user.id],
       [nil, "google"], [nil, google_uid]]
    )
  end

  def login_and_respond(user, _google_uid, payload)
    unless user.status == rodauth.account_open_status_value
      return render json: { error: "account_not_active" },
                    status: :unprocessable_entity
    end

    session[rodauth.session_key] = user.id
    session[rodauth.authenticated_by_session_key] = ["google_one_tap"]
    rodauth.remember_login

    backfill_name(user, payload)

    render json: { ok: true, redirect: "/" }
  end

  def backfill_name(user, payload)
    return unless user.name.blank?

    name = payload["name"]
    user.update!(name: name) if name.present?
  end
end
```

**Key decisions:**
- `skip_forgery_protection` because the JWT itself is the authentication proof
- Raw SQL for identity queries (no AR model exists; Sequel manages this table)
- Account status check prevents login to unverified/locked accounts
- Name backfill mirrors the existing `after_login` hook behavior
- Rescue specific exceptions in `verify_google_token` to avoid silent failures

---

### Task 3: Add Route

**File:** `config/routes.rb`

Add after the MCP endpoint (line 56):

```ruby
# Google One Tap sign-in
post "auth/google/one_tap", to: "google_one_tap_sessions#create"
```

---

### Task 4: Create the Phlex Component

**File:** `app/components/google_one_tap.rb`

```ruby
# frozen_string_literal: true

module Components
  class GoogleOneTap < Components::Base
    def view_template
      return unless show?

      div(
        data: {
          controller: "google-one-tap",
          google_one_tap_client_id_value: ENV["GOOGLE_CLIENT_ID"],
          google_one_tap_login_path_value: "/auth/google/one_tap"
        },
        style: "display:none"
      )
    end

    private

    def show?
      ENV["GOOGLE_CLIENT_ID"].present? &&
        !view_context.rodauth.logged_in?
    end
  end
end
```

**Why hidden div:** The component is a controller-only mount point. One Tap renders its own UI (a Google-styled popup in the corner). No visible HTML needed.

---

### Task 5: Integrate into Application Layout

**File:** `app/views/layouts/application_layout.rb`

Add `render Components::GoogleOneTap.new` inside the `body` tag, after `FlashToasts`:

```ruby
body(...) do
  render Components::FlashToasts.new
  render Components::GoogleOneTap.new   # <-- ADD THIS LINE
  render Components::PwaInstallBanner.new
  # ... rest unchanged
end
```

This ensures One Tap is available on every page for logged-out users. The component self-guards (only renders when Google is configured and user is not logged in).

---

### Task 6: Write Request Specs

**File:** `spec/requests/google_one_tap_sessions_spec.rb`

Test cases:

1. **Valid JWT, existing identity** → returns `{ ok: true }`, sets session
2. **Valid JWT, no identity but matching account** → creates identity, returns `{ ok: true }`
3. **Valid JWT, no matching account** → returns `{ error: "no_account" }` with redirect
4. **Valid JWT, account not active** → returns `{ error: "account_not_active" }`
5. **Invalid JWT** → returns `{ error: "invalid_token" }`
6. **Missing credential** → returns `{ error: "invalid_token" }`
7. **JWT with wrong audience** → returns `{ error: "invalid_token" }`
8. **Name backfill** → updates user name when blank

**Mocking approach:** Stub `Net::HTTP.get_response` to return mock Google tokeninfo responses. Example:

```ruby
let(:google_payload) do
  {
    "sub" => "google-uid-123",
    "email" => user.email,
    "email_verified" => "true",
    "name" => "Jane Doe",
    "aud" => "test-google-client-id"
  }
end

before do
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID").and_return("test-google-client-id")

  mock_response = instance_double(Net::HTTPSuccess, body: google_payload.to_json)
  allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
  allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
end
```

---

### Task 7: Write System Spec

**File:** `spec/system/google_one_tap_spec.rb`

Test:
1. **Component renders when Google configured** → visit `/`, check for `[data-controller="google-one-tap"]`
2. **Component absent when Google not configured** → stub ENV, visit `/`, check no controller div
3. **Component absent when logged in** → log in, visit `/`, check no controller div

**Note:** Cannot test actual One Tap interaction in system tests (requires real Google session). Focus on component visibility.

---

### Task 8: Pre-commit Validation

Run in order:
1. `bundle exec rake project:fix-lint`
2. `bundle exec rake project:lint`
3. `bundle exec rake project:tests`
4. `bundle exec rake project:system-tests`

---

## 5. Validation Gates

### Gate 1: Unit/Request Tests Pass

```bash
eval "$(rbenv init -)" && bundle exec rspec spec/requests/google_one_tap_sessions_spec.rb
```

**Expected:** All 8 test cases green.

### Gate 2: System Tests Pass

```bash
eval "$(rbenv init -)" && bundle exec rspec spec/system/google_one_tap_spec.rb
```

**Expected:** Component visibility tests pass.

### Gate 3: Full Test Suite

```bash
eval "$(rbenv init -)" && bundle exec rake project:tests
eval "$(rbenv init -)" && bundle exec rake project:system-tests
```

**Expected:** No regressions.

### Gate 4: Lint

```bash
eval "$(rbenv init -)" && bundle exec rake project:fix-lint
eval "$(rbenv init -)" && bundle exec rake project:lint
```

**Expected:** Clean.

### Gate 5: Runtime Verification

1. `bin/cli app rebuild && bin/cli app restart`
2. Visit `https://catalyst.workeverywhere.docker/` (logged out) with `agent-browser`
3. **Verify:** `[data-controller="google-one-tap"]` element present in DOM
4. **Verify:** GIS script tag (`accounts.google.com/gsi/client`) loaded
5. Log in via test helper, revisit home page
6. **Verify:** `[data-controller="google-one-tap"]` element NOT present
7. Existing Google OAuth button on `/login` still renders and functions

### Gate 6: Manual Google Testing (Requires Real Credentials)

If `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set in `.env.development`:
1. Visit home page in browser with active Google session
2. One Tap prompt should appear
3. Click to approve → should be logged in
4. Log out → revisit → should auto-sign-in (auto_select)

---

## 6. Reference Documentation

### Google Identity Services

| Resource | URL |
|----------|-----|
| GIS Overview | https://developers.google.com/identity/gsi/web/guides/overview |
| JS API Reference | https://developers.google.com/identity/gsi/web/reference/js-reference |
| Display One Tap | https://developers.google.com/identity/gsi/web/guides/use-one-tap-js-api |
| FedCM Migration | https://developers.google.com/identity/gsi/web/guides/fedcm-migration |
| Integration Guide | https://developers.google.com/identity/gsi/web/guides/integrate |
| One Tap Codelab | https://codelabs.developers.google.com/codelabs/google-one-tap |

### Backend Token Verification

| Resource | URL |
|----------|-----|
| Verify ID Token | https://developers.google.com/identity/gsi/web/guides/verify-google-id-token |
| tokeninfo endpoint | `https://oauth2.googleapis.com/tokeninfo?id_token=TOKEN` |

### Rodauth / OmniAuth

| Resource | URL |
|----------|-----|
| rodauth-omniauth README | https://github.com/janko/rodauth-omniauth |
| rodauth-rails OmniAuth wiki | https://github.com/janko/rodauth-rails/wiki/OmniAuth |
| Social Login in Rails with Rodauth (blog) | https://janko.io/social-login-in-rails-with-rodauth/ |

### Stimulus

| Resource | URL |
|----------|-----|
| Stimulus Handbook | https://stimulus.hotwired.dev/handbook/introduction |
| Stimulus Reference | https://stimulus.hotwired.dev/reference/controllers |

### Gotchas & Pitfalls

1. **GIS exponential cooldown**: If a user dismisses One Tap, Google suppresses it for increasing periods (2 hours → 1 day → 1 week → 4 weeks). This is by design and cannot be overridden. Don't treat "prompt not showing" as a bug.

2. **FedCM browser support**: FedCM is Chrome 117+. Other browsers fall back to the legacy One Tap UI. Using `use_fedcm_for_prompt: true` handles this gracefully.

3. **`auto_select` requirements**: Auto-sign-in only triggers when (a) exactly one Google session is active, (b) that session previously approved the app, and (c) the user hasn't opted out. First-time users always see the interactive prompt.

4. **Turbo and script loading**: The GIS script is loaded dynamically by the Stimulus controller. On Turbo navigations, `disconnect()` cancels the prompt and `connect()` re-initializes. Ensure `data: { turbo: false }` is NOT needed here (unlike the OAuth button) because we're using fetch, not form submission.

5. **tokeninfo endpoint latency**: Each verification makes a network call to Google. For high-traffic apps, consider switching to local JWT verification with Google's public keys (cached). For this app's scale, tokeninfo is fine.

6. **SQLite and concurrent writes**: The identity INSERT uses a single statement. SQLite's WAL mode handles this fine for this app's concurrency level.

7. **Rodauth session keys**: The session key names come from Rodauth's configuration. Use `rodauth.session_key` and `rodauth.authenticated_by_session_key` — don't hardcode string values.

8. **`skip_forgery_protection`**: Only skip for the One Tap endpoint. The JWT credential + audience verification serves as the authentication proof. This is the standard pattern recommended by Google's integration guide.

---

## Quality Checklist

- [x] All necessary context included (Rodauth config, views, routes, session management, existing Google setup)
- [x] Validation gates are executable by AI (specific commands, expected outcomes)
- [x] References existing patterns (test_sessions_controller for session creation, login.rb for Google conditional)
- [x] Clear implementation path (8 ordered tasks with code examples)
- [x] Error handling documented (invalid token, no account, inactive account, network errors)
- [x] Security considerations documented (CSRF, JWT verification, account status, no auto-creation)
- [x] Edge cases documented (cooldown, multiple accounts, Turbo navigation, FedCM fallback)
