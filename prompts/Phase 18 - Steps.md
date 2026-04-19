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

_TBD_

---

## 3. Commits

_TBD_

---

## 4. Runtime verification

_TBD_

---

## 5. PR + review

_TBD_

---

## 6. Final summary

_TBD_
