# Phase 17: Onboarding Improvements — Round 2 (Passkey UX)

**Status:** Draft
**Date:** 2026-04-19
**Confidence Score:** 8/10 (all touch points are in our own code; the only open question is the exact quality of the auto-suggested passkey title, which depends on the User-Agent string and the AAGUID visibility — both fall back gracefully to a user-editable text field)

---

## 1. Context

Follow-up to [Phase 16 — Onboarding Improvements](https://github.com/joel/trip/pull/103). Phase 16 cleaned up the logged-out entry flow; Phase 17 cleans up the **logged-in passkey surface** that the invited user first sees.

**Observations from live use at `https://catalyst.workeverywhere.docker/`:**

1. The logged-in home page shows a large "Security / Add a passkey" card (`render_passkey_card` in `app/views/welcome/home.rb:157`). This card is the very first thing an invited user sees after signing up — before they ever see a trip. It's visual noise for anyone who already has a passkey and friction for anyone who doesn't care to add one right now.

2. The sidebar shows **both** "Add passkey" and "Manage passkeys" at the same time once any passkey is registered (`app/components/sidebar.rb:164-177`). "Add passkey" is the odd one out: it should disappear once a user has at least one passkey and reappear only from inside the manage-passkeys screen.

3. The `/webauthn-remove` screen currently only lists existing passkeys with a "Last used: …" label. Users can't tell a 1Password entry from a Mac-fingerprint entry from a Pixel-phone entry — they're all identical timestamps. Passkeys need a human-readable **title**, ideally auto-suggested at registration time and editable by the user.

4. The `/webauthn-remove` screen has no way to add another passkey — the user has to hunt for the sidebar link. Once "Add passkey" is hidden from the sidebar (point 2), the manage screen must become the single place to add a new one.

5. On successful sign-in the app lands on `/` (Rodauth's default `login_redirect`). For a logged-in user with at least one trip, the meaningful destination is `/trips`, not the passkey-heavy home. Per the user's ask: **"Once connected the user must be redirected to `/trips` instead of having the Passkey Panel that mean nothing."**

Passkeys stay optional — none of the changes here gate trip access on having a passkey. This phase is pure information-architecture + one small data addition (the passkey name column).

---

## 2. Reference Documentation

| Resource | URL |
|----------|-----|
| Rodauth WebAuthn Feature | https://rodauth.jeremyevans.net/rdoc/files/doc/webauthn_rdoc.html |
| Rodauth WebAuthn Setup (auth-value methods) | https://rodauth.jeremyevans.net/rdoc/files/doc/webauthn_rdoc.html#label-Auth+Value+Methods |
| `webauthn_keys_account_id_column` / `webauthn_keys_table` | https://rodauth.jeremyevans.net/rdoc/files/doc/webauthn_rdoc.html |
| `account_webauthn_usage` internals | https://github.com/jeremyevans/rodauth/blob/master/lib/rodauth/features/webauthn.rb |
| `webauthn-ruby` gem (AAGUID on credential) | https://github.com/cedarcode/webauthn-ruby |
| FIDO Alliance AAGUID registry | https://github.com/passkeydeveloper/passkey-authenticator-aaguids |
| Rails 8.1 Guides — Migrations (add_column) | https://guides.rubyonrails.org/active_record_migrations.html |
| Phlex Rails Components | https://www.phlex.fun/rails |
| Tailwind CSS 4 docs | https://tailwindcss.com/docs |

---

## 3. Scope

### What this phase changes

1. **Remove the homepage passkey panel.** `render_passkey_card` and its call-site in `render_info_cards` come out of `app/views/welcome/home.rb`.
2. **Sidebar is mutually exclusive.** Show "Add passkey" **or** "Manage passkeys", never both. The predicate is `view_context.rodauth.webauthn_setup?` (true when the user has ≥1 passkey on file).
3. **Add an "Add another passkey" CTA on `/webauthn-remove`.** The manage screen becomes the canonical place to register additional passkeys.
4. **Passkey titles.** New column `user_webauthn_keys.name` (nullable). The setup form collects a title, pre-filled with a sensible auto-suggestion derived from the incoming User-Agent and the AAGUID of the credential when available. The remove screen displays `name — Last used: <ts>` and falls back to `"Passkey — Last used: <ts>"` for legacy rows where `name IS NULL`.
5. **Post-sign-in redirect.** `login_redirect` and `webauthn_setup_redirect` both resolve to `/trips`. `create_account_redirect` for invited signups also resolves to `/trips` (previously `/`).

### What this phase does NOT change

- The `/webauthn-setup` screen stays at the same URL; only its form gains a `name` field.
- The `/webauthn-auth` (sign-in via passkey) screen is untouched.
- WebAuthn autofill on `/login` is untouched.
- The Rodauth config for origin / RP ID / RP name is untouched.
- No change to invitation, access-request, verify-account, or email-auth flows.
- No change to the schema of `users`, `invitations`, `access_requests`, or any Rodauth-owned table other than the single `add_column :user_webauthn_keys, :name`.
- No migration of existing passkey rows — legacy rows show "Passkey" as their label until the user re-registers or we add an edit flow (out of scope here).
- No change to the policies layer.

---

## 4. Existing Codebase Context

### Relevant files

| File | Current behaviour |
|------|------------------|
| `app/views/welcome/home.rb:132-177` | `render_info_cards` renders a 2-col grid with `render_users_card` and `render_passkey_card`. The passkey card links to `webauthn_setup_path` and conditionally to `webauthn_remove_path` when `rodauth.webauthn_setup?` is true. |
| `app/components/sidebar.rb:157-178` | `render_logged_in_links` always renders "Add passkey" and additionally renders "Manage passkeys" when `rodauth.webauthn_setup?` is true. |
| `app/views/rodauth/webauthn_remove.rb` | Lists each key via `account_webauthn_usage.each do |id, last_use|`, labelled only with `"Last used: #{formatted_use}"`. No add-new-passkey CTA. |
| `app/views/rodauth/webauthn_setup.rb` | Renders a minimal form with challenge + challenge HMAC hidden fields and a single submit button. No name input. |
| `app/misc/rodauth_main.rb:7-220` | Configures the Rodauth auth class. `logout_redirect "/"` is set; `login_redirect` and `webauthn_setup_redirect` use Rodauth defaults (`/`). `create_account_redirect { "/" }` at line 68. |
| `db/schema.rb:240-247` | `user_webauthn_keys` has compound PK `(user_id, webauthn_id)` plus `last_use`, `public_key`, `sign_count`. No `name` column. |
| `spec/system/webauthn_autofill_spec.rb` + `spec/requests/webauthn_autofill_spec.rb` | Existing coverage of the autofill feature — not affected by this phase but should stay green. |

### Rodauth internals worth citing

- **`webauthn_setup?`** — auth-value method returning true when the account has ≥1 row in `user_webauthn_keys`. Already used in both sidebar and home.
- **`account_webauthn_usage`** — returns `{ webauthn_id => last_use_timestamp, ... }` for the current account. Used to render the remove list. We'll replace it with a direct query so we can also surface the name column.
- **`add_webauthn_credential(credential)`** — inserts the new row into `user_webauthn_keys`. It ignores unknown columns, so the `name` value needs to be written in a hook after the row is inserted (simplest path: `after_webauthn_setup` hook that updates the just-inserted row by `webauthn_id`).
- **`webauthn_setup_redirect`** — auth-value method, defaults to `require_login_redirect` → `/`. Overridable to `/trips`.
- **`login_redirect`** — auth-value method, defaults to `/`. Overridable to `/trips`.
- **`after_webauthn_setup`** — post-insert hook. `webauthn_id` is available here as the credential ID string; we can use it as the row key to write `name`.
- **Param access** — `param_or_nil("passkey_name")` inside the Rodauth auth class reads the submitted form field.

### Auto-suggested title derivation

The suggestion is a best-effort hint computed once at GET `/webauthn-setup` and shown in the input's `placeholder` and as the `value` (user editable). Two inputs:

1. **AAGUID**: the `webauthn-ruby` gem exposes `credential.response.authenticator_data.attested_credential_data.aaguid` after attestation. Mapped against the public [passkey-authenticator-aaguids](https://github.com/passkeydeveloper/passkey-authenticator-aaguids) registry, we get strings like `"Apple iCloud Keychain"`, `"1Password"`, `"Bitwarden"`, `"Google Password Manager"`, `"Windows Hello"`. **However** — the AAGUID isn't available until the browser returns the attestation, i.e. after the user taps the submit button. So this path fills the name **in the after-setup hook on the server**, not as a pre-filled placeholder.

2. **User-Agent**: available on GET `/webauthn-setup`. We parse it into a coarse label:
   - `"iPhone"` / `"iPad"` → `"iPhone"` / `"iPad"`
   - `"Macintosh"` + Safari → `"Mac (Safari)"`, + Chrome → `"Mac (Chrome)"`, etc.
   - `"Android"` + known device name → `"<device>"`, else `"Android phone"`
   - `"Windows NT"` → `"Windows PC"`
   - Fallback → `"Passkey"`

**Strategy** (prioritises correctness without blocking):
- On GET, pre-fill the input with the UA-derived hint. User can edit before submitting.
- On successful POST, if the submitted `name` is blank (user cleared it), use the AAGUID lookup result if available; else fall back to the UA hint; else `"Passkey"`.
- Truncate to 60 chars.

This keeps the happy path simple (most users hit the UA suggestion and accept it) and gives us a known-good fallback chain.

---

## 5. Implementation Plan

### Task 1 — Remove the homepage passkey panel

**File:** `app/views/welcome/home.rb`

- Delete `render_passkey_card` (lines 157-177).
- In `render_info_cards`, remove the `render_passkey_card` call. If `render_users_card` is the only survivor and only renders conditionally (`allowed_to?(:index?, User)`), wrap it so the section collapses cleanly for users without that permission:
  ```ruby
  def render_info_cards
    return unless view_context.allowed_to?(:index?, User)

    div(class: "grid gap-6 md:grid-cols-2") do
      render_users_card
    end
  end
  ```
  (Alternatively, if this leaves `render_info_cards` one-card-only for everyone, switch to a single-column layout with `max-w-md` to avoid the half-empty grid.)

### Task 2 — Sidebar: mutually exclusive passkey links

**File:** `app/components/sidebar.rb`

Change `render_logged_in_links` (lines 157-179) from an additive pattern to an exclusive one:

```ruby
def render_logged_in_links
  render Components::NavItem.new(
    path: view_context.account_path,
    label: "My account",
    icon: Components::Icons::Person.new,
    delay: "260ms"
  )
  if view_context.rodauth.webauthn_setup?
    render Components::NavItem.new(
      path: view_context.rodauth.webauthn_remove_path,
      label: "Manage passkeys",
      icon: Components::Icons::KeyRemove.new,
      delay: "300ms"
    )
  else
    render Components::NavItem.new(
      path: view_context.rodauth.webauthn_setup_path,
      label: "Add passkey",
      icon: Components::Icons::Key.new,
      delay: "300ms"
    )
  end
  render_logout_button
end
```

### Task 3 — `/webauthn-remove`: add the "Add another passkey" CTA

**File:** `app/views/rodauth/webauthn_remove.rb`

- At the top of the manage-passkeys card (after the hero/title block, before the form), insert a link styled as a secondary button pointing at `webauthn_setup_path`:
  ```ruby
  div(class: "ha-card p-6") do
    p(class: "ha-overline") { plain "Security" }
    h2(class: "mt-2 text-lg font-semibold") { plain "Add another passkey" }
    p(class: "mt-2 text-sm text-[var(--ha-muted)]") do
      plain "Register another device for faster, safer sign-ins."
    end
    div(class: "mt-4") do
      link_to("Add passkey",
              view_context.rodauth.webauthn_setup_path,
              class: "ha-button ha-button-primary")
    end
  end
  ```
- Include `Phlex::Rails::Helpers::LinkTo` at the top of the class.
- Keep the existing "Manage passkeys" remove form untouched.
- Update the radio-button label to include the passkey name (see Task 4).

### Task 4 — Passkey titles

#### 4a. Migration

**File:** `db/migrate/<timestamp>_add_name_to_user_webauthn_keys.rb` (new)

```ruby
class AddNameToUserWebauthnKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :user_webauthn_keys, :name, :string, limit: 80
  end
end
```

Nullable on purpose: legacy rows have no name until the user re-registers that key.

#### 4b. Setup form: add the "Passkey name" input

**File:** `app/views/rodauth/webauthn_setup.rb`

- Include `Phlex::Rails::Helpers::Request` (or access `view_context.request.user_agent`).
- Before the submit button, add a text input:
  ```ruby
  suggested_name = Webauthn::NameSuggester.from_user_agent(
    view_context.request.user_agent
  )
  div(class: "space-y-2") do
    label(class: "text-sm font-medium") { "Passkey name" }
    form.text_field(
      "passkey_name",
      value: suggested_name,
      maxlength: 60,
      class: "ha-input",
      autocomplete: "off",
      placeholder: "e.g. Mac fingerprint, Pixel phone, Bitwarden"
    )
    p(class: "text-xs text-[var(--ha-muted)]") do
      plain "Give this device a name you’ll recognise later."
    end
  end
  ```

#### 4c. Name suggester

**File:** `app/misc/webauthn/name_suggester.rb` (new)

A small PORO that maps a User-Agent string to a friendly label. One method, `from_user_agent(ua)`, returns a String, capped at 60 chars, defaulting to `"Passkey"`. No dependency on any gem — simple regex matches are enough; the goal is a reasonable hint, not perfect device fingerprinting.

**File:** `app/misc/webauthn/aaguid_lookup.rb` (new)

A static Hash mapping the handful of AAGUIDs we care about (iCloud Keychain, 1Password, Bitwarden, Google Password Manager, Windows Hello, Chrome Profile) to human strings. Build from the public [passkey-authenticator-aaguids registry](https://github.com/passkeydeveloper/passkey-authenticator-aaguids). One method, `lookup(aaguid_string)`, returns a String or nil.

Keeping these as POROs under `app/misc/webauthn/` matches the existing `app/misc/rodauth_main.rb` placement convention.

#### 4d. Persist the name on setup

**File:** `app/misc/rodauth_main.rb`

Add an `after_webauthn_setup` hook inside `configure`:

```ruby
after_webauthn_setup do
  submitted = param_or_nil("passkey_name").to_s.strip
  name = if submitted.present?
           submitted[0, 60]
         else
           aaguid = extract_aaguid(new_webauthn_credential)
           Webauthn::AaguidLookup.lookup(aaguid) ||
             Webauthn::NameSuggester.from_user_agent(request.user_agent) ||
             "Passkey"
         end

  db[:user_webauthn_keys]
    .where(user_id: account_id, webauthn_id: new_webauthn_credential.id)
    .update(name: name)
end
```

`extract_aaguid` is a small private helper in the same file that digs `aaguid` out of the webauthn-ruby credential object, returning a UUID string or nil.

#### 4e. Display the name on remove

**File:** `app/views/rodauth/webauthn_remove.rb`

Replace the `account_webauthn_usage.each` block with a direct query that also pulls the name. Example:

```ruby
keys = ::User
         .connection
         .execute(
           "SELECT webauthn_id, last_use, name FROM user_webauthn_keys " \
           "WHERE user_id = ? ORDER BY last_use DESC",
           view_context.rodauth.account_id
         )
keys.each do |row|
  id         = row["webauthn_id"]
  last_use   = row["last_use"]
  name_label = row["name"].presence || "Passkey"
  formatted  = last_use ? Time.parse(last_use.to_s).strftime(...) : "Never"
  # ... render label with "#{name_label} — Last used: #{formatted}"
end
```

Prefer Sequel through `db[...]` (matching the Rodauth DB conn) over raw `ActiveRecord::Base.connection.execute` if it keeps the auth/user-scope boundary clean; both are acceptable — pick the one that matches the existing `db[:user_webauthn_keys]` pattern we introduce in 4d.

### Task 5 — Post-sign-in redirect to /trips

**File:** `app/misc/rodauth_main.rb`

Inside `configure`:

```ruby
login_redirect "/trips"
webauthn_setup_redirect "/trips"
create_account_redirect { "/trips" }   # replaces current "/"
```

`logout_redirect "/"` and `verify_account_redirect { login_redirect }` stay as they are (after logout, home is the right place).

**Note:** The existing `after_login` hook at lines 205-214 still runs before the redirect — no change there.

### Task 6 — Tests

#### Model / action specs

None required — no changes to models or actions in this phase.

#### Request specs

**File:** `spec/requests/rodauth/webauthn_setup_spec.rb` (new)

- `GET /webauthn-setup` renders the form with a visible `passkey_name` input.
- `POST /webauthn-setup` with a valid credential + custom `passkey_name` persists the name on the inserted row.
- `POST /webauthn-setup` with a valid credential + blank `passkey_name` falls back to a UA-derived name.
- After successful setup, response redirects to `/trips`.

**File:** `spec/requests/rodauth/webauthn_remove_spec.rb` (new or extend)

- `GET /webauthn-remove` shows one entry per passkey with its `name` label.
- `GET /webauthn-remove` shows an "Add passkey" CTA linking to `/webauthn-setup`.

#### System specs

**File:** `spec/system/passkey_management_spec.rb` (new)

Five flows, all against a seeded logged-in user:

1. Home page no longer shows the "Add a passkey" panel (`expect(page).not_to have_selector(".ha-card", text: "Add a passkey")` on `/`).
2. Sidebar shows "Add passkey" when the user has **no** passkeys; does **not** show "Manage passkeys".
3. Sidebar shows "Manage passkeys" when the user has **≥1** passkey; does **not** show "Add passkey".
4. `/webauthn-remove` shows the "Add another passkey" link.
5. After sign-in via email-auth (the canonical flow for invited users in this project), the user lands on `/trips`, not `/`.

For flow 3, pre-seed a `user_webauthn_keys` row directly (we can't register a real passkey from a headless browser without stubbing WebAuthn). Flow 5 uses the existing email-auth seam (`spec/system/invitations_spec.rb` pattern).

#### Spec updates

**File:** `spec/system/welcome_spec.rb`

- Drop any assertion that the passkey panel is visible on the logged-in home.
- Add negative assertion: the logged-in home no longer contains the text "Add a passkey" or "Register a passkey per device".

**File:** `spec/system/invitations_spec.rb`

- Update the Phase 16 auto-login expectation: post-signup, user now lands on `/trips` instead of `/`. Adjust `expect(current_path).to eq("/")` → `expect(current_path).to eq("/trips")`.

---

## 6. Files to Create

| File | Purpose |
|------|---------|
| `db/migrate/<ts>_add_name_to_user_webauthn_keys.rb` | `add_column :user_webauthn_keys, :name, :string, limit: 80` |
| `app/misc/webauthn/name_suggester.rb` | UA → friendly passkey label |
| `app/misc/webauthn/aaguid_lookup.rb` | AAGUID → authenticator name |
| `spec/requests/rodauth/webauthn_setup_spec.rb` | Name persistence + redirect on setup |
| `spec/requests/rodauth/webauthn_remove_spec.rb` | Name display + Add-passkey CTA on remove |
| `spec/system/passkey_management_spec.rb` | Home panel gone, sidebar mutex, /trips redirect |

## 7. Files to Modify

| File | Change |
|------|--------|
| `app/views/welcome/home.rb` | Delete `render_passkey_card`; update `render_info_cards` (Task 1) |
| `app/components/sidebar.rb` | Mutually exclusive Add / Manage passkey links (Task 2) |
| `app/views/rodauth/webauthn_remove.rb` | Add "Add another passkey" CTA; display passkey name next to last-used (Tasks 3 + 4e) |
| `app/views/rodauth/webauthn_setup.rb` | Add "Passkey name" input with UA-derived pre-fill (Task 4b) |
| `app/misc/rodauth_main.rb` | `after_webauthn_setup` hook; `login_redirect`, `webauthn_setup_redirect`, `create_account_redirect` to `/trips` (Tasks 4d + 5) |
| `spec/system/welcome_spec.rb` | Drop panel assertion (Task 6) |
| `spec/system/invitations_spec.rb` | Update post-signup redirect assertion to `/trips` (Task 6) |

---

## 8. Key Design Decisions

1. **Keep `verify_account` alone.** Phase 16 already handled the verify-account fast-path for invited signups; this phase piggybacks on that without changing it. The only Rodauth flag we touch is redirects + one new hook.

2. **Name column, not a separate table.** A `passkey_credentials` side table would be more normalised but buys nothing today (passkeys already have a 1:1 relationship with `user_webauthn_keys` rows). One nullable column is the minimum viable change, reversible via a rollback migration.

3. **Auto-suggest > require.** The user-facing field is pre-filled and editable. We never block setup because the name is empty — we fall back (submitted → AAGUID → UA → `"Passkey"`). This matches the rest of the onboarding philosophy from Phase 16 (don't introduce friction).

4. **Sidebar mutual exclusion, not "show both + grey one out".** Either the user has no passkey (one action: add) or they have at least one (one action: manage, which itself leads to add). Two active calls-to-action at once is what surfaced as confusing in live use.

5. **`/trips` as the post-sign-in home.** For a trip-journaling app, the destination is trips. The current `/` has become a dashboard-style summary; it's useful, but it's *after* the user has picked a trip, not the landing point. Moving `login_redirect` doesn't remove `/` — it's still reachable from the sidebar "Overview" link.

6. **No edit-name flow for existing passkeys.** Out of scope. Legacy rows stay `name IS NULL` and show as `"Passkey"`. If this bites in practice, a follow-up phase can add an inline-edit on `/webauthn-remove` — but committing to it now risks scope-creep when the Round-2 cleanup is primarily about removing panels and redirecting.

7. **AAGUID lookup as a static Hash, not a gem.** The [passkey-authenticator-aaguids](https://github.com/passkeydeveloper/passkey-authenticator-aaguids) list covers ~40 entries; the ones our user base will hit are a handful (iCloud Keychain, 1Password, Bitwarden, Google PM, Windows Hello, Chrome Profile). A static Hash keeps the dependency surface zero; we can expand or switch to a gem later if the list grows unmanageable.

8. **`after_webauthn_setup` + row UPDATE rather than overriding `add_webauthn_credential`.** The override path is brittle (Rodauth internals can change the column set or the insert path between versions). The hook is stable and does exactly what we need: "after Rodauth inserted the row, write the extra column we own."

---

## 9. Risks

1. **User-Agent auto-suggestions can be wrong or awkward** (e.g. Safari on iPad says `"iPad"` but WebKit on iOS also claims `iPad` from desktop-mode). **Mitigation:** the field is editable and clearly labelled. The cost of a wrong suggestion is one keystroke.

2. **AAGUID may be absent** on older authenticators or when attestation is `"none"` (the default in Rodauth's webauthn-ruby config). **Mitigation:** the UA fallback catches this; worst case we land at `"Passkey"` and the user edits.

3. **The remove screen's direct SQL query** ([Task 4e](#4e-display-the-name-on-remove)) sidesteps `account_webauthn_usage`. If Rodauth changes the column set or table name between versions, this query drifts. **Mitigation:** the project already has direct SQL patterns (e.g. the Rodauth Sequel DB handle in `rodauth_main.rb`), and the table/column names here are stable Rodauth-configured values (`webauthn_keys_table`). An alternative is to keep calling `account_webauthn_usage` for the `id → last_use` map and do a single extra query for `id → name`, merging in Ruby — cleaner but more code. The plan prefers the single query; the reviewer should flag if they prefer the merge approach.

4. **Changing `login_redirect` to `/trips` globally** affects every sign-in path, not just invited signups. An admin signing in also lands on `/trips`. **Mitigation:** this is the ask ("Once connected"), and the sidebar "Overview" link is always one click away. If this turns out to be wrong for the admin role, a follow-up can branch on `current_user.role?(:superadmin)` inside `login_redirect { ... }`.

5. **Tests that stub WebAuthn credential creation** are heavy. **Mitigation:** for unit/request-level assertions (Task 6), we can insert the row directly into `user_webauthn_keys` and assert rendering; we don't need to drive a real WebAuthn attestation ceremony. The existing `spec/system/webauthn_autofill_spec.rb` shows the pattern.

6. **Tailwind JIT** — the new `ha-input` usage on the setup form and all existing `ha-button` classes are already compiled. No new custom class is introduced. A Docker rebuild is **not** required for CSS reasons, but `bin/cli app rebuild` is mandatory anyway for the migration to run and for `/product-review` to pass.

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
bin/cli app rebuild   # picks up the migration
bin/cli app restart
bin/cli mail start
```

Then with `agent-browser` against `https://catalyst.workeverywhere.docker/`:

**Logged-in home (`/`)**
- [ ] No "Add a passkey" card anywhere on the page
- [ ] Users card still renders for superadmin
- [ ] Layout doesn't look half-empty for non-admin users

**Sidebar (no passkeys registered)**
- [ ] "Add passkey" link is visible
- [ ] "Manage passkeys" link is **not** visible

**Sidebar (≥1 passkey registered)**
- [ ] "Manage passkeys" link is visible
- [ ] "Add passkey" link is **not** visible

**Passkey registration (`/webauthn-setup`)**
- [ ] A "Passkey name" text input is present, pre-filled with a sensible UA-based suggestion (e.g. `"Mac (Chrome)"` on a Mac Chrome session)
- [ ] Submitting the form with a custom name persists that exact name
- [ ] Submitting the form with a blank name persists the UA fallback (or AAGUID if available)
- [ ] After success, the browser lands on `/trips`

**Manage passkeys (`/webauthn-remove`)**
- [ ] Each listed passkey shows `"<name> — Last used: <ts>"` rather than only a timestamp
- [ ] Legacy rows (if any) show `"Passkey — Last used: <ts>"`
- [ ] An "Add another passkey" button/link is visible and routes to `/webauthn-setup`
- [ ] Removing a passkey still works end-to-end

**Post-sign-in redirect**
- [ ] Complete an email-auth sign-in → lands on `/trips`
- [ ] Complete an invitation signup (invited flow from Phase 16) → lands on `/trips`
- [ ] Sign out → lands on `/`

### Security Gates (per `/security-review` skill)

```bash
mise x -- bundle exec brakeman --no-pager
mise x -- bundle exec bundle-audit check --update
```

Pay particular attention to:
- The raw SQL in `webauthn_remove.rb` — make sure `account_id` is passed as a bound parameter, not interpolated.
- The `after_webauthn_setup` hook — `param_or_nil("passkey_name")` is user input; it's trimmed and length-capped at 60 before insertion.
- No new XSS paths: the name is rendered through Phlex's `plain` helper, which escapes by default. Flag any `unsafe_raw` / `raw` on this surface.

### GitHub Workflow (per `/execution-plan` skill)

1. Create an issue on [Trip Issues](https://github.com/joel/trip/issues) titled **"Phase 17: Onboarding Improvements — Round 2 (Passkey UX)"** with a link to this plan.
2. Add labels: `feature`, `cleanup`, `ux`.
3. Move through Backlog → Ready → In Progress on the [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1).
4. Branch: `feature/phase17-passkey-ux`.
5. One PR covering all five tasks (they share the passkey surface and are tightly coupled).
6. Move to In Review on PR open; respond to every review comment; resolve every conversation.

---

## 11. Task Order (one PR, atomic commits per task)

1. **Commit 1** — Remove passkey panel from logged-in home (Task 1 + `welcome_spec` update)
2. **Commit 2** — Sidebar: mutually exclusive Add/Manage passkey (Task 2 + system spec flows 2 + 3)
3. **Commit 3** — Add migration + name column scaffolding (Task 4a only — just the DDL, keeps the commit small and rollback-easy)
4. **Commit 4** — Setup form collects passkey name; after-setup hook persists it (Tasks 4b, 4c, 4d + setup request spec)
5. **Commit 5** — Remove screen displays names + adds Add-passkey CTA (Tasks 3 + 4e + remove request spec)
6. **Commit 6** — `login_redirect` / `webauthn_setup_redirect` / `create_account_redirect` → `/trips` (Task 5 + invitations + passkey_management system specs)

Each commit is independently reversible. All six touch runtime code; **no `[skip ci]`** on any of them. No `SKIP=<Hook>` needed unless the migration+schema check flags a false positive (document if so).

---

## 12. Quality Checklist

- [x] All five user-reported issues mapped to a concrete task
- [x] All new code paths have a matching spec
- [x] Validation gates are executable by project skills
- [x] References existing Rodauth + Phlex + Tailwind patterns
- [x] Clear commit ordering, each commit independently valid
- [x] Risks identified and mitigated
- [x] No changes to public API, MCP surface, or schema shape of any existing table other than one additive nullable column
- [x] Backwards-compatible: legacy passkey rows render cleanly without the new column
- [x] Mandatory `/product-review` coverage plan is explicit (pages + exact expectations)
