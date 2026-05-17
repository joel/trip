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

### Tasks 4–7 — wiring, gallery, ui_library, specs

- `4675d57` wire JournalEntryCard cover+grid into the lightbox; extracted
  `ImageLightbox` mixin to stay within `Metrics/ClassLength`.
- `328e4fa` gallery route/controller/policy (`TripPolicy#gallery? == show?`,
  eager-load to avoid N+1).
- `88c764c` `Views::Trips::Gallery` flat grid + action-bar link; extracted
  `render_insight_links` to stay within `Metrics/CyclomaticComplexity`.
- `aab30eb` ui_library entries (lightbox, overlay, gallery) + regen index.
- `9a84d2c` request specs (gallery 200 member/viewer, 403 non-member, empty
  state) + system specs (`:js` lightbox open/nav/Esc + cover trigger).

### Step 6 — Full validation

- `rake project:lint` 490/0; `project:tests` 768/0 (2 pre-existing pending);
  `project:system-tests` 88/0.
- `bdca…` (test): two **pre-existing** audit-log system defects were unmasked
  by the mandatory asset rebuild (no audit code in this branch): `:30`
  asserted `"Agent"` vs an intentionally `uppercase` badge (Selenium reads the
  CSS-transformed `"AGENT"`; only passed on `main` because the committed CSS
  was stale); `:49` used `page.status_code`, unsupported by the JS driver
  (fails on `main` too). Both fixed test-only with rationale.

### Step 8 — Live runtime verification (agent-browser)

- `bin/cli app rebuild` + `restart` + mail; passwordless sign-in via
  MailCatcher; trip `Japan Spring Tour` (8 photos).
- Verified: "Gallery" action-bar link; cover image opens lightbox
  (counter `1 / 1`, ESC closes); Gallery flat 8-thumb grid + "Back to trip";
  thumbnail opens lightbox with caption `Last Day in Osaka · 29 Apr 2026`,
  counter `1 / 8` → `2 / 8`; dark mode; no console/network errors.
- **Bug found + fixed live:** overlay sized `944×572` not full viewport — a
  transformed app-shell ancestor was the containing block for the fixed
  overlay. Fixed by portalling the overlay to `<body>` on connect and wiring
  controls via explicit listeners (commit on branch). Re-verified:
  `parent: BODY`, `position: fixed`, `1280×720`, full-cover; visually correct
  (scrim, centered contained image, counter, close, chevrons, caption).

### Step 2–3 — Kanban (still blocked)

- `gh project` scopes still ungranted; board move deferred (documented above).
  Issue #145 remains the source of truth; PR `Closes #145`.

## Step 9–10 — PR

- Pushed `feature/phase-22-image-experience`; opened PR
  [#146](https://github.com/joel/trip/pull/146), `Closes #145`.
- Kanban "In Review" move still blocked (gh project scopes). Needs manual
  board move or `gh auth refresh -s read:project,project`.

## Final summary

| Item | Commits | Status |
|------|---------|--------|
| #145 Image-centric experience | `6a618fd` docs · `19a7fa3` controller · `112b268` components · `4675d57` card wiring · `328e4fa` gallery route · `88c764c` gallery view · `aab30eb` ui_library · `9a84d2c` specs · audit test fix · portal fix · steps | PR #146 open, all gates green; awaiting review + manual Kanban move |

## Step 11 — CI fix + review response

CI (`test`) failed on first run; root causes (CI runs non-`:js` system
specs under `rack_test` + `assets:precompile`, no libvips):

| Failure | Cause | Fix |
|---------|-------|-----|
| `trip_gallery:21,:44` | `variant()` raises `LoadError` (libvips absent on CI); `rescue StandardError` doesn't catch `LoadError` → gallery 500 | `73965f4` rescue `StandardError, LoadError` → original-image fallback (card + gallery) |
| `audit_logs:30` | `have_text("AGENT")` is Selenium-only (CSS uppercase); rack_test DOM is raw "Agent" glued to prior node | `292922f` `have_text(/AGENT|Agent/)` cross-driver |
| `audit_logs:51` | `head :not_found` → rack_test has no `<html>` (have_no_text raises); Selenium has no status_code | `292922f` branch on `Capybara::RackTest::Driver` |
| PR P1 review | Turbo cached the body-portalled overlay; restore reconnect had no in-element overlay | `3b9cdba` return overlay home on `turbo:before-cache`/`disconnect`; guard `open()` |

Validated locally green under **both** drivers: `spec/system` 88/0 on
Selenium and on `TEST_BROWSER=rack_test`; non-system 768/0; rubocop 490/0.
PR #146 P1 comment replied (`3b9cdba`) and thread resolved. Kanban: #145
added to board and moved to **In review**.
