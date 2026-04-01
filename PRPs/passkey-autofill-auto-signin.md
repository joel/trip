# PRP: Passkey Autofill Auto Sign-In (Conditional Mediation)

**Status:** Draft
**Date:** 2026-04-01
**Type:** Feature
**Confidence Score:** 9/10 (Rodauth has a built-in feature for this; changes are small and well-scoped)

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

Users who have registered a passkey must go through a multi-step flow to use it:
1. Navigate to `/login`
2. Type their email address
3. Submit the form
4. Arrive at the multi-phase login page
5. Click "Use a passkey"
6. Authenticate with their device biometrics

This defeats the purpose of passkeys being faster than passwords.

### Desired State

When a user visits the login page and their device has a registered passkey for this app, the browser should **automatically offer the passkey in the email field's autofill dropdown** (alongside any saved passwords). The user can select their passkey, authenticate with biometrics, and be logged in immediately — **without typing their email or navigating to a second page**.

This is called **WebAuthn Conditional Mediation** (or "Passkey Autofill"). It uses `navigator.credentials.get({ mediation: "conditional" })` to register with the browser's autofill system, presenting passkeys when the user focuses an input with `autocomplete="... webauthn"`.

### Key Behaviors

1. **Login page with passkey on device**: Email field shows passkey in autofill dropdown; selecting it authenticates immediately
2. **Login page without passkey**: Normal flow unchanged — type email, get multi-phase login
3. **New passkey registrations**: Will enforce `residentKey: 'required'` so passkeys are always discoverable
4. **Existing passkeys**: Most modern platforms (macOS, Windows Hello, iOS, Android) create discoverable credentials by default, so existing passkeys will likely work
5. **Browser without conditional mediation support**: Graceful no-op — the JS checks `PublicKeyCredential.isConditionalMediationAvailable()` first

### Non-Goals

- Showing passkey autofill on non-login pages (conditional mediation is scoped to the login page)
- Changing the passkey registration flow
- Supporting non-discoverable credentials for autofill

---

## 2. Codebase Context

### Authentication Architecture

| Area | Technology | Key File |
|------|-----------|----------|
| Auth framework | Rodauth 2.43.0 (via rodauth-rails) | `app/misc/rodauth_main.rb` |
| WebAuthn features | `:webauthn`, `:webauthn_login` | `app/misc/rodauth_main.rb:8-9` |
| WebAuthn gem | `webauthn` (via Rodauth) | `Gemfile:40` |
| Login view | Phlex | `app/views/rodauth/login.rb` |
| Login form | Phlex component | `app/components/rodauth_login_form.rb` |
| Multi-phase login | Phlex | `app/views/rodauth/multi_phase_login.rb` |
| Layout | Phlex | `app/views/layouts/application_layout.rb` |
| WebAuthn auth view | Phlex | `app/views/rodauth/webauthn_auth.rb` |

### Rodauth's Built-In `webauthn_autofill` Feature

Rodauth 2.43.0 ships with a `:webauthn_autofill` feature that provides everything needed. It is **not currently enabled**.

**Source:** `/home/joel/.local/share/mise/installs/ruby/4.0.1/lib/ruby/gems/4.0.0/gems/rodauth-2.43.0/lib/rodauth/features/webauthn_autofill.rb`

When enabled, it automatically:

1. **Changes `login_field_autocomplete_value`** on the login page from `"email"` to `"email webauthn"` — the browser uses this to offer passkeys in autofill
2. **Adds a JS route** (`webauthn_autofill_js_path`) serving the conditional mediation JavaScript
3. **Returns empty `allowCredentials`** when no account is identified — required for discoverable credential autofill
4. **Enforces `residentKey: 'required'`** for new passkey registrations via `webauthn_authenticator_selection`
5. **Overrides `account_from_webauthn_login`** to look up accounts by credential ID (since no email is typed)
6. **Provides JavaScript** (`webauthn_autofill.js`) that handles the full flow:
   - Checks `PublicKeyCredential.isConditionalMediationAvailable()`
   - Calls `navigator.credentials.get({ mediation: "conditional", publicKey: opts })`
   - Fills a hidden form field with the assertion data
   - Submits the form to `webauthn_login_path`

### The Complication: Custom Phlex Views

The codebase uses custom Phlex views instead of Rodauth's default templates. Rodauth's `_login_form_footer` method normally auto-appends the autofill form, but our `RodauthLoginFormFooter` component reads `login_form_footer_links` directly and doesn't call `_login_form_footer`.

**This means we must manually render the hidden autofill form in the login view.**

### Key Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `app/misc/rodauth_main.rb` | **MODIFY** | Add `:webauthn_autofill` to the `enable` list |
| `app/components/webauthn_autofill.rb` | **CREATE** | Phlex component rendering the hidden form + autofill JS |
| `app/views/rodauth/login.rb` | **MODIFY** | Render the autofill component |
| `spec/requests/webauthn_autofill_spec.rb` | **CREATE** | Specs for autofill form rendering and autocomplete attribute |
| `spec/system/webauthn_autofill_spec.rb` | **CREATE** | System specs for autofill form visibility |

### Key Files to Reference (Read-Only)

| File | Why |
|------|-----|
| `app/views/rodauth/webauthn_auth.rb` | Pattern for rendering WebAuthn credential options in Phlex |
| `app/components/google_one_tap.rb` | Pattern for conditional auto-sign-in component |
| `app/components/rodauth_login_form.rb` | Uses `login_field_autocomplete_value` (auto-updated by the feature) |
| `spec/system/google_one_tap_spec.rb` | Pattern for component visibility system specs |
| `spec/requests/google_one_tap_sessions_spec.rb` | Pattern for auth request specs |

### Rodauth's Autofill JavaScript (Built-In)

**Source:** `rodauth-2.43.0/javascript/webauthn_autofill.js`

```javascript
(function() {
  var pack = function(v) { return btoa(String.fromCharCode.apply(null, new Uint8Array(v))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, ''); };
  var unpack = function(v) { return Uint8Array.from(atob(v.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0)); };
  var element = document.getElementById('webauthn-login-form');

  if (!window.PublicKeyCredential || !PublicKeyCredential.isConditionalMediationAvailable) return;

  PublicKeyCredential.isConditionalMediationAvailable().then(function(available) {
    if (!available) return;

    var opts = JSON.parse(element.getAttribute("data-credential-options"));
    opts.challenge = unpack(opts.challenge);
    opts.allowCredentials.forEach(function(cred) { cred.id = unpack(cred.id); });

    navigator.credentials.get({mediation: "conditional", publicKey: opts}).then(function(cred) {
      // ... packs credential data ...
      document.getElementById('webauthn-auth').value = JSON.stringify(authValue);
      element.submit();
    });
  });
})();
```

**Key requirements from this JS:**
- Element with `id="webauthn-login-form"` containing `data-credential-options` (JSON)
- Hidden input with `id="webauthn-auth"` inside that form
- Form action pointing to `webauthn_login_path`

### Rodauth's Autofill Template (Reference)

**Source:** `rodauth-2.43.0/templates/webauthn-autofill.str`

```html
<form method="post" action="#{rodauth.webauthn_login_path}"
      id="webauthn-login-form"
      data-credential-options="#{(cred = rodauth.webauthn_credential_options_for_get).as_json.to_json}">
  #{rodauth.webauthn_auth_additional_form_tags}
  #{rodauth.csrf_tag(rodauth.webauthn_login_path)}
  <input type="hidden" name="#{rodauth.webauthn_auth_challenge_param}" value="#{cred.challenge}" />
  <input type="hidden" name="#{rodauth.webauthn_auth_challenge_hmac_param}" value="#{rodauth.compute_hmac(cred.challenge)}" />
  <input type="text" name="#{rodauth.webauthn_auth_param}" id="webauthn-auth" value="" />
  #{rodauth.button(rodauth.webauthn_auth_button, class: "d-none")}
</form>
<script src="#{rodauth.webauthn_js_host}#{rodauth.webauthn_autofill_js_path}"></script>
```

Our Phlex component must reproduce this structure.

---

## 3. Technical Approach

### Architecture Overview

```
Login page loads
  │
  ├─ Email field has autocomplete="email webauthn"
  │    (automatically set by Rodauth's webauthn_autofill feature)
  │
  ├─ Hidden form #webauthn-login-form rendered by Components::WebauthnAutofill
  │    - Contains challenge, HMAC, CSRF token
  │    - Contains credential options as data attribute
  │
  ├─ Rodauth's webauthn_autofill.js loaded via <script>
  │    - Checks PublicKeyCredential.isConditionalMediationAvailable()
  │    - Calls navigator.credentials.get({ mediation: "conditional" })
  │    - Registers with browser's autofill system (no modal shown)
  │
  ▼ User focuses email field
  │
  ├─ Browser shows autofill dropdown with passkey option
  │
  ▼ User selects passkey → biometric verification
  │
  ├─ JS fills #webauthn-auth hidden field with assertion data
  ├─ JS submits #webauthn-login-form
  │
  ▼ POST to webauthn_login_path (Rodauth handles this)
  │
  ├─ webauthn_autofill feature's account_from_webauthn_login
  │    looks up account by credential ID (no email needed)
  ├─ Rodauth verifies assertion, logs user in
  ├─ after_login hook: remember_login + name backfill
  └─ Redirect to login_redirect (home page)
```

### Why This Is Simpler Than Google One Tap

| Aspect | Google One Tap | Passkey Autofill |
|--------|---------------|-----------------|
| New controller | Yes (GoogleOneTapSessionsController) | **No** — Rodauth handles POST |
| New route | Yes (POST /auth/google/one_tap) | **No** — uses existing webauthn_login_path |
| Custom JavaScript | Yes (Stimulus controller) | **No** — Rodauth provides webauthn_autofill.js |
| JWT verification | Yes (tokeninfo endpoint) | **No** — Rodauth verifies WebAuthn assertion |
| Session creation | Manual | **Automatic** — Rodauth's login flow |
| Remember cookie | Manual (account_from_id) | **Automatic** — after_login hook |

### What Changes

1. **`rodauth_main.rb`**: Add `:webauthn_autofill` to enabled features (1 line)
2. **`Components::WebauthnAutofill`**: New Phlex component (~40 lines)
3. **`Views::Rodauth::Login`**: Render the component (1 line)
4. **Specs**: Request + system specs

### Security Considerations

- **No new attack surface** — the autofill form submits to Rodauth's existing `webauthn_login_path` with standard CSRF protection
- **Challenge/HMAC** — prevents replay attacks (same as existing WebAuthn auth)
- **`residentKey: 'required'`** — ensures new passkeys are discoverable credentials
- **Browser mediation** — the browser controls when passkeys are shown; the site cannot force credential selection

---

## 4. Implementation Tasks

### Task 1: Enable `:webauthn_autofill` in Rodauth Config

**File:** `app/misc/rodauth_main.rb`

Change line 8-9 from:
```ruby
enable :create_account, :verify_account, :login, :logout,
       :email_auth, :webauthn, :webauthn_login, :omniauth, :remember
```

To:
```ruby
enable :create_account, :verify_account, :login, :logout,
       :email_auth, :webauthn, :webauthn_login, :webauthn_autofill,
       :omniauth, :remember
```

**This activates:**
- `login_field_autocomplete_value` → `"email webauthn"` on login page
- `webauthn_autofill_js_path` route (serves the JS)
- `webauthn_authenticator_selection` → `residentKey: 'required'`
- `account_from_webauthn_login` → lookup by credential ID
- `webauthn_allow` → empty `allowCredentials` for logged-out users

---

### Task 2: Create the Phlex Component

**File:** `app/components/webauthn_autofill.rb`

This component mirrors the structure of Rodauth's `webauthn-autofill.str` template.

```ruby
# frozen_string_literal: true

module Components
  class WebauthnAutofill < Components::Base
    include Phlex::Rails::Helpers::JavaScriptIncludeTag

    def view_template
      return unless show?

      cred = view_context.rodauth.webauthn_credential_options_for_get

      form(
        method: "post",
        action: view_context.rodauth.webauthn_login_path,
        id: "webauthn-login-form",
        data: {
          credential_options: cred.as_json.to_json,
          turbo: "false"
        },
        style: "display:none"
      ) do
        raw safe(
          view_context.rodauth.webauthn_auth_additional_form_tags.to_s
        )
        raw safe(
          view_context.rodauth.csrf_tag(
            view_context.rodauth.webauthn_login_path
          )
        )

        input(
          type: "hidden",
          name: view_context.rodauth.webauthn_auth_challenge_param,
          value: cred.challenge
        )
        input(
          type: "hidden",
          name: view_context.rodauth
                            .webauthn_auth_challenge_hmac_param,
          value: view_context.rodauth.compute_hmac(cred.challenge)
        )
        input(
          type: "text",
          name: view_context.rodauth.webauthn_auth_param,
          id: "webauthn-auth",
          value: "",
          class: "hidden",
          aria: { hidden: "true" }
        )
      end

      javascript_include_tag(
        view_context.rodauth.webauthn_autofill_js_path,
        extname: false
      )
    end

    private

    def show?
      view_context.rodauth.features.include?(:webauthn_autofill) &&
        view_context.rodauth.webauthn_autofill? &&
        !view_context.rodauth.logged_in?
    end
  end
end
```

**Key decisions:**
- `style: "display:none"` hides the form visually (the JS handles everything)
- `data: { turbo: "false" }` prevents Turbo from intercepting `element.submit()`
- CSRF tag included via `rodauth.csrf_tag(webauthn_login_path)` (the Rodauth template does this explicitly)
- `show?` checks both feature availability and login state
- Uses `form()` (raw HTML) instead of `form_with` because the JS expects a specific `id` and submits via `element.submit()`

---

### Task 3: Add Component to Login View

**File:** `app/views/rodauth/login.rb`

Add `render Components::WebauthnAutofill.new` inside `render_login_panel`, after the login form and before the Google section:

```ruby
def render_login_panel
  div(class: "ha-glass rounded-[2rem] p-8 " \
             "shadow-[var(--ha-card-shadow)]") do
    # ... existing header ...

    div(class: "mt-6") do
      render Components::RodauthLoginForm.new
    end

    render Components::WebauthnAutofill.new  # <-- ADD THIS

    render_google_section if google_configured?

    render Components::RodauthLoginFormFooter.new
  end
end
```

**Why here:** The autofill JS runs on page load and registers with the browser. It must be on the same page as the email input with `autocomplete="email webauthn"`. The form is hidden, so visual placement doesn't matter.

---

### Task 4: Write Request Specs

**File:** `spec/requests/webauthn_autofill_spec.rb`

Test cases:

1. **Feature is enabled in Rodauth** — verify `:webauthn_autofill` is in features list
2. **Login field autocomplete includes webauthn** — GET `/login`, check email field has `autocomplete="email webauthn"`
3. **Autofill form is rendered on login page** — check for `#webauthn-login-form` with `data-credential-options`
4. **Autofill JS is loaded** — check for script tag with `webauthn_autofill_js` path
5. **Authenticator selection requires resident key** — verify `webauthn_authenticator_selection` includes `residentKey: 'required'`

---

### Task 5: Write System Specs

**File:** `spec/system/webauthn_autofill_spec.rb`

Test cases:

1. **Autofill form present on login page** — visit `/login`, check for `#webauthn-login-form`
2. **Autofill form absent when logged in** — login, visit `/login`, check form not present
3. **Email field has correct autocomplete** — visit `/login`, check input has `autocomplete` containing `webauthn`

---

### Task 6: Pre-Commit Validation

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```

---

## 5. Validation Gates

### Gate 1: Feature Enabled

```bash
mise x -- bundle exec rspec spec/requests/webauthn_autofill_spec.rb
```

### Gate 2: System Tests

```bash
mise x -- bundle exec rspec spec/system/webauthn_autofill_spec.rb
```

### Gate 3: Full Test Suite (No Regressions)

```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```

### Gate 4: Lint

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
```

### Gate 5: Runtime Verification

1. `bin/cli app rebuild && bin/cli app restart`
2. Visit `https://catalyst.workeverywhere.docker/login` with `agent-browser`
3. **Verify:** `#webauthn-login-form` element present in DOM
4. **Verify:** Email input has `autocomplete` containing `webauthn`
5. **Verify:** Script tag for webauthn autofill JS is loaded
6. Log in, revisit `/login`
7. **Verify:** `#webauthn-login-form` NOT present

### Gate 6: Manual Passkey Testing (Requires Real Device)

If testing locally with a registered passkey:
1. Visit `/login`
2. Focus the email field
3. Browser should show passkey in autofill dropdown
4. Select passkey → authenticate with biometrics
5. Should be logged in and redirected to home page

---

## 6. Reference Documentation

### WebAuthn Conditional Mediation

| Resource | URL |
|----------|-----|
| Rodauth webauthn_autofill docs | https://rodauth.jeremyevans.net/rdoc/files/doc/webauthn_autofill_rdoc.html |
| Passkey Authentication with Rodauth (blog) | https://janko.io/passkey-authentication-with-rodauth/ |
| Sign in with passkey through form autofill (web.dev) | https://web.dev/articles/passkey-form-autofill |
| Chrome identity docs: WebAuthn conditional UI | https://developer.chrome.com/docs/identity/webauthn-conditional-ui |
| WebAuthn Conditional UI explainer (W3C) | https://github.com/w3c/webauthn/wiki/Explainer:-WebAuthn-Conditional-UI |
| Yubico: Simple Autofill Flow | https://developers.yubico.com/WebAuthn/Concepts/Passkey_Autofill/Implementation_Guidance/Simple_Autofill_Flow.html |
| Corbado: WebAuthn Conditional UI technical explanation | https://www.corbado.com/blog/webauthn-conditional-ui-passkeys-autofill |

### Rodauth Source (Local Gem)

| File | Purpose |
|------|---------|
| `rodauth-2.43.0/lib/rodauth/features/webauthn_autofill.rb` | Feature definition (65 lines) |
| `rodauth-2.43.0/javascript/webauthn_autofill.js` | Conditional mediation JS (38 lines) |
| `rodauth-2.43.0/templates/webauthn-autofill.str` | Default template (reference for Phlex port) |
| `rodauth-2.43.0/lib/rodauth/features/webauthn_login.rb` | Login route handler |

### Browser Support

| Browser | Conditional Mediation Since |
|---------|---------------------------|
| Chrome | 108+ |
| Edge | 108+ |
| Safari | 16+ |
| Firefox | 119+ |

### Gotchas & Pitfalls

1. **Existing passkeys and `residentKey`**: Enabling `webauthn_autofill` changes `webauthn_authenticator_selection` to require `residentKey: 'required'`. However, most modern platforms already create discoverable credentials by default, so existing passkeys should work. Only very old or non-platform authenticators (e.g., older USB security keys) might not create discoverable credentials.

2. **Custom Phlex views bypass `_login_form_footer`**: Rodauth's `webauthn_autofill` feature normally appends the autofill form via `_login_form_footer`. Since our Phlex views don't call this method, we must render the component explicitly in the login view.

3. **Form ID must be `webauthn-login-form`**: The built-in `webauthn_autofill.js` hardcodes `document.getElementById('webauthn-login-form')`. The hidden input must have `id="webauthn-auth"`. These IDs are not configurable.

4. **`data-turbo="false"` is essential**: The JS calls `element.submit()` directly. Without disabling Turbo on this form, the submission may be intercepted and fail.

5. **No abort controller in Rodauth's JS**: The built-in `webauthn_autofill.js` does not use an `AbortController`. If the user navigates away via Turbo before selecting a passkey, the pending `navigator.credentials.get()` call may linger. This is generally harmless — the browser handles cleanup — but be aware of it.

6. **Conditional mediation is non-blocking**: `navigator.credentials.get({ mediation: "conditional" })` returns a Promise that stays pending until the user interacts with autofill. It does NOT show a modal. The user can ignore it and proceed with the normal email-based flow.

7. **The autofill form only renders on `/login`**: The `show?` method in the component checks `!rodauth.logged_in?`. The `login_field_autocomplete_value` override in Rodauth only adds `webauthn` on `login_path`. So the autofill is properly scoped to the login page.

---

## Quality Checklist

- [x] All necessary context included (Rodauth feature source, JS source, template structure, Phlex patterns)
- [x] Validation gates are executable by AI (specific commands, expected outcomes)
- [x] References existing patterns (webauthn_auth.rb for credential options, google_one_tap for component pattern)
- [x] Clear implementation path (5 tasks, mostly 1-line changes + 1 new component)
- [x] Error handling documented (graceful degradation for unsupported browsers)
- [x] Security considerations documented (CSRF, challenge/HMAC, no new attack surface)
- [x] Gotchas documented (Phlex bypass, hardcoded IDs, Turbo, non-blocking mediation)
