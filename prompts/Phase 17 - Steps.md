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

## 4. Branch

- **Branch:** `feature/phase17-passkey-ux`
