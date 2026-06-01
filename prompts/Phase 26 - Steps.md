# Phase 26 — Re-attachable Media · Steps (flight recorder)

Append-only. Why and in what order, readable top-to-bottom.

Plan: `prompts/Phase 26 Re-attachable Media.md`.

---

## Step 1 — Issue

- **Issue:** [#196](https://github.com/joel/trip/issues/196) — "Phase 26 —
  Re-attachable attachments (soft-delete for Active Storage)". Deferred from
  Phase 25 (`prompts/Phase 25 Improve Persistance.md` §9); pre-existing.
- **Plan:** `prompts/Phase 26 Re-attachable Media.md` — **APPROVED 2026-06-01**.
  D1 images+videos; D2 Activity-feed restore; D3 soft-delete + restore only
  (no user purge this phase). Cascade: entry-discard cascades to videos,
  **parent-only restore** (mirror Phase 25).
- Label: `enhancement`. Kanban: added to board → Ready → In Progress.

## Step 4 — Branch

- `feature/phase-26-reattachable-media` off `main`.
