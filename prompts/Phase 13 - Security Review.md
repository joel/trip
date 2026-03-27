# Security Review -- feature/catalyst-glass-design-system

**Date:** 2026-03-27
**Branch:** `feature/catalyst-glass-design-system`
**Reviewer:** Automated adversarial security review
**Scope:** 35 files changed, +1771 / -605 lines -- primarily CSS, Phlex component templates, and view files

---

## Critical (must fix before merge)

No critical findings.

---

## Warning (should fix or consciously accept)

### 1. Role label exposed in sidebar, user cards, and account details

**Files:** `app/components/sidebar.rb:244-250`, `app/components/user_card.rb` (`role_label`), `app/components/account_details.rb` (`role_label`), `app/components/mobile_top_bar.rb`

**Observation:** The new sidebar user profile section displays `user_role_label` (e.g., "Super Admin", "Admin", "Member") in the sidebar panel text visible to the logged-in user. The `user_card.rb` and `account_details.rb` components also render role chips for each user.

**Risk:** Low. The role label is shown from `current_user` in the sidebar (the user seeing their own role), which is expected. In `user_card.rb` and `account_details.rb`, any user visible on those pages already requires authorization via `allowed_to?(:index?, User)`. However, displaying the "Super Admin" label to non-admin users viewing user cards could reveal which accounts have elevated privileges. This is informational -- it does not enable privilege escalation, but it does reveal the admin topology.

**Recommendation:** Consider showing the role chip only when the current user has admin privileges, or accept this as an intentional UX decision.

### 2. Email local part used as display name fallback

**Files:** `app/components/sidebar.rb:232`, `app/views/welcome/home.rb:240`, `app/components/mobile_top_bar.rb:52`

**Observation:** When a user has no `name` set, the code falls back to `email.split("@").first` (sidebar, home) or `email&.first` (mobile top bar, single character). This exposes partial email addresses in the rendered HTML.

**Risk:** Very low. The email is already known to the authenticated user (it is their own email). The sidebar and mobile top bar only render for the currently logged-in user. No other user's email local part is exposed through this path.

**Recommendation:** Acceptable as-is. No action needed.

---

## Informational (no action required)

### 1. UUID removal from user cards -- positive change

The previous implementation rendered `##{@user.id}` (full UUID) in `user_card.rb` and `account_details.rb`. This branch removes that display entirely, replacing it with avatar initials and role chips. This is a minor security improvement -- UUIDs are no longer leaked in HTML output for user cards.

### 2. Pre-existing `raw()` usage unchanged

Two existing `raw()` calls remain in the codebase:
- `app/views/journal_entries/show.rb:101` -- `raw(safe(@entry.body.to_s))` for rendering Action Text rich content
- `app/views/rodauth/create_account.rb:30` -- `raw safe(view_context.rodauth.create_account_additional_form_tags.to_s)` for Rodauth CSRF tags

Both pre-existed on `main` and were not introduced or modified by this branch. They use Phlex's `safe()` wrapper and render framework-generated content, not arbitrary user input.

### 3. No new `unsafe_raw` or `html_safe` calls

Grep across the entire `app/` directory confirms no new `unsafe_raw` or `html_safe` calls were introduced.

### 4. CSS `style` attribute interpolation is safe

`app/components/checklist_card.rb:45` uses `style: "width: #{pct}%"` where `pct` is computed as `(completed.to_f / total * 100).round` -- always an Integer between 0 and 100. No user-controlled input reaches this interpolation.

### 5. Active trip query is properly scoped

`app/views/welcome/home.rb:232` uses `user&.trips&.find_by(state: :started)` which queries through the user's `has_many :trips` association. This correctly scopes to trips the current user is a member of.

### 6. Authorization checks preserved

All existing `allowed_to?` checks in views and components are preserved:
- `MobileBottomNav`: Users tab gated by `allowed_to?(:index?, User)`
- `Sidebar`: Users, Requests, Invitations tabs gated by appropriate policy checks
- `TripCard`, `JournalEntryCard`: Edit links gated by `allowed_to?(:edit?, @record)`
- `TripsIndex`, `TripsShow`: Create/delete actions gated by policy
- No authorization checks were removed or weakened

### 7. External resource: Google Fonts

The CSS imports fonts from `https://fonts.googleapis.com/css2?...`. The Inter font family was added to the existing import URL. This is a standard, trusted CDN. The `display=swap` parameter is used to prevent Flash of Invisible Text (FOIT).

### 8. Tailwind `@source` directives are build-time only

The new `@source` directives in `application.css` point to `../../views`, `../../components`, and `../../../app/javascript`. These are processed at build time by Tailwind CSS v4 for class scanning and have no runtime security implications.

---

## Not applicable

| Category | Reason |
|----------|--------|
| **New routes / controllers** | No new routes, controllers, or models were added. |
| **Authentication changes** | No changes to Rodauth configuration or authentication flows. |
| **Authorization policy changes** | No policy files were modified. Existing `allowed_to?` checks are preserved. |
| **Strong parameters** | No controller changes; no new params handling. |
| **Database / migrations** | No schema changes, no new migrations. |
| **Mass assignment** | No model changes. |
| **Raw SQL** | No SQL introduced. |
| **File uploads** | No changes to upload handling. Existing `file_field` for journal entry images is unchanged. |
| **Secrets / credentials** | No secrets, tokens, `.env` files, or credentials in the diff. |
| **Dependencies** | No new gems (Gemfile unchanged), no new npm packages. |
| **Invitation/token flows** | No changes to token handling. |

---

## Summary

This branch is a visual design system overhaul with no functional security impact. All changes are confined to CSS variables, Tailwind utility classes, Phlex component templates, and view layout restructuring. No new routes, controllers, models, policies, or authentication logic were introduced or modified.

The one minor observation (Warning #1 -- role labels visible to non-admin users) is a UX design decision rather than a vulnerability. The pre-existing security posture (Rodauth authentication, ActionPolicy authorization, Phlex auto-escaping, UUID primary keys) remains intact and unmodified.

**Verdict: Clear to merge from a security perspective.**
