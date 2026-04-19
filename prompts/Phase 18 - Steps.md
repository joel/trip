# Phase 18 — Steps (audit trail)

> Append-only log of decisions, commits, and verifications.
> Plan: [`prompts/Phase 18 Navigation Improvements.md`](Phase%2018%20Navigation%20Improvements.md).

---

## 1. Issue + plan

- **Issue:** [#114 — Phase 18: Navigation Improvements](https://github.com/joel/trip/issues/114) (label: `enhancement`).
- **Plan:** `prompts/Phase 18 Navigation Improvements.md`.
- **User approved the plan** after two rounds of clarification:
  - Round 1 fixed: Sign-out on Account = yes; viewer hides all three (Members/Checklists/Exports); zero-trips → friendly empty-state copy; remove Overview/Home entirely; redirect by trip count.
  - Round 2 reversed Overview/Home removal — `/` becomes a smart router instead. Rules:
    - 0 trips → empty-state.
    - 1 trip → that trip.
    - 2+ trips with ≥1 `started` → most recently updated `started` trip.
    - 2+ trips, none `started` → `/trips` index (confirmed fallback).
- **Deferred:** "only one started trip at a time" model constraint — out of scope, tracked as future work.

---

## 2. Branch

- `feature/phase18-navigation` (off `main`).

---

## 3. Commits

1. `0c3e99c` — Add Sign-out button to Account show page (Task 1).
2. `ec4c54b` — Restrict trip viewers from Members, Checklists, Exports (Task 2: policy tightening + button guards).
3. `13d5ce6` — Make `/` a smart router with empty-state fallback (Task 3: controller redirect logic, dead-helper cleanup, request + system spec coverage for all four router branches).

---

## 4. Runtime verification

- `bin/cli app rebuild` / `app restart` — health check `GET /up` returned 200.
- `bin/cli mail start` — container `mail` up.
- `agent-browser` sweep of logged-out `/` — renders "Welcome to Catalyst" + "Request an invitation" + "Request Access" (screenshot `tmp/phase18/01_logged_out.png`).
- **Logged-in smart-router branches:** seed accounts are passkey-only (`get_password_hash` returns nil, only joel/gin/jack have a registered passkey), so a fresh agent-browser session can't drive login without CDP WebAuthn virtual-authenticator setup. Coverage for the four branches comes from the 4 Capybara system specs in `spec/system/welcome_spec.rb` (real browser engine, `login_as` helper bypasses Rodauth) plus 5 request specs in `spec/requests/welcome_spec.rb`. All 9 green.
- Full validation gate: `rake project:fix-lint` (clean), `project:lint` (clean), `project:tests` (620 examples, 0 failures, 2 pre-existing pending), `project:system-tests` (78 examples, 0 failures).

---

## 5. PR + review

_TBD_

---

## 6. Final summary

_TBD_
