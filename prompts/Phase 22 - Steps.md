# Phase 22 — Image-Centric Experience · Steps (flight recorder)

Append-only. Why and in what order, readable top-to-bottom.

---

## Step 1 — Issue

- **Issue:** [#145](https://github.com/joel/trip/issues/145) — "Phase 22: Image-centric experience — lightbox + trip gallery"
- **Plan:** `prompts/Phase 22 UX Improvements.md` (= `PRPs/phase-22-image-experience.md`)
- User approved the plan on 2026-05-17; clarifying questions Q1–Q5 resolved in §1 of the plan.
- Label: `enhancement`.

## Step 2–3 — Kanban (BLOCKED, non-fatal)

- `gh project item-add` failed: token missing `read:project`/`project` scopes (keyring auth; `gh auth refresh` is interactive). Board move to Backlog→Ready→In Progress deferred until scopes granted. Work proceeds — tracking gap noted here so it can be reconciled before merge.

## Step 4 — Branch

- `feature/phase-22-image-experience` off `main`.

## Step 5 — Implementation

### Task 2 — Stitch MCP design flow

- Wrote input brief `prompts/Phase 22 - Image Experience - Google Stitch Prompt.md`.
- MCP: `list_projects` → `Catalyst` (`projects/3314239195447065678`);
  `list_design_systems` → captured full **Catalyst Glass** spec + all `--ha-*`
  tokens (`assets/3c209c99f89947168c4e8320f9465cdc`).
- `generate_screen_from_text` (Gallery, DESKTOP, design system applied) returned
  an async **timeout** — Stitch's documented "can take minutes / DO NOT RETRY"
  behaviour. `list_screens` showed no persisted Gallery/Lightbox screen within
  the session window.
- Per plan §14 the established token system is authoritative. Implementation is
  grounded in the captured Catalyst Glass system + its canonical in-repo
  realisation (Phase 21 Activity page = sibling for a new per-trip page;
  `JournalEntryCard#render_images` = photo-grid pattern). Recorded in
  `designs/stitch_trip_gallery/README.md`. No visual invention; `ha-*` + `--ha-*`
  only.

### Task 3 — Lightbox controller + components

- `app/javascript/controllers/lightbox_controller.js` (~170 lines, under the
  ~250 ceiling → pure Stimulus stands, no PhotoSwipe pivot). open/close/wrap nav,
  arrow keys, Esc, Tab focus-trap, touch swipe, body-scroll-lock, disconnect
  cleanup, single-image nav hide.
- `app/components/lightbox_overlay.rb` — shared viewer chrome (dialog markup +
  Stimulus targets).
- `app/components/lightbox.rb` — self-contained flat-grid group for the Gallery.
  Fixed `grid_class` to literal Tailwind classes (JIT cannot see interpolation).
