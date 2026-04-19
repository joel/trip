# Phase 17 — Onboarding Improvements Round 2 (Passkey UX) — Steps

Flight recorder for Phase 17. Append-only.

## 1. Issue

- **Issue:** [joel/trip#112](https://github.com/joel/trip/issues/112) — "Phase 17: Onboarding Improvements — Round 2 (Passkey UX)"
- **Plan:** `prompts/Phase 17 Onboarding Improvements Round 2.md`
- **Status:** User approved the plan on 2026-04-19, including the three open questions:
  - Global `login_redirect` change (admins + invited users both land on `/trips`) — **approved**.
  - Deferring edit-name flow for legacy passkeys to a later phase — **approved**.
  - Direct-SQL on `/webauthn-remove` rather than merge-in-Ruby — **approved**.

## 2. Kanban

- The local `gh` token is missing `read:project` / `project` scopes — Kanban moves need to be made manually (or after `gh auth refresh -s project`). Recording the intended transitions so they can be applied after the fact:
  - Backlog → Ready → In Progress (start of work)
  - In Progress → In Review (PR open)
  - In Review → Done (merge)

## 9. PR

- **PR:** [joel/trip#113](https://github.com/joel/trip/pull/113) — "Phase 17: Passkey UX round 2 — names, mutex, /trips redirect"

## 4. Branch

- **Branch:** `feature/phase17-passkey-ux`

## 7. Commits

| SHA | Subject | Notes |
|-----|---------|-------|
| `3b4b9fe` | Add Phase 17 plan and steps scaffolding | Doc-only, `[skip ci]`. |
| `e7b4844` | Remove passkey panel from logged-in home | Task 1. Info cards now single-column, admin-only. |
| `4e94977` | Make sidebar passkey link mutually exclusive | Task 2. Extracts `passkey_nav_attrs` to keep Metrics/ClassLength happy. |
| `51801e8` | Add name column to user_webauthn_keys | Task 4a. Nullable string(80) additive migration. |
| `24bf033` | Collect passkey name on setup and persist it | Task 4b/c/d. `webauthn_key_insert_hash` override, UA + AAGUID fallbacks. |
| `5a70b0d` | Show passkey names and Add-another CTA on /webauthn-remove | Task 3 + 4e. Direct-SQL via `exec_query` with bound `account_id`. |
| `ec35fb1` | Land post-auth flows on /trips instead of home | Task 5. `login_redirect`/`create_account_redirect`/`webauthn_setup_redirect`. |

## 8. Runtime verification

Browser walk via `agent-browser` against `https://catalyst.workeverywhere.docker/`:

- Logged-out home still shows only the "Request an invitation" card.
- Sign-in via email-auth lands on **/trips** (login_redirect applied).
- Logged-in home: no "Add a passkey" card; "Stay connected" users card
  centred alone.
- Sidebar with ≥1 passkey: shows **Manage passkeys**, hides **Add passkey**.
- `/webauthn-remove`: top card is "Add another passkey" with a primary
  link to `/webauthn-setup`; legacy passkey row renders as
  `"Passkey — Last used: 2026-04-18 13:48:20"` (name column NULL).
- `/webauthn-setup`: "Passkey name" input visible, pre-filled with
  `"Linux device"` (UA-derived suggestion from the browser's agent).
- `/account`, `/users`, `/trips` all render cleanly.

Security gates clean: `brakeman` 0 warnings, `bundle-audit` 0
vulnerabilities.
