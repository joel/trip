# PRP: Phase 22 — Image-Centric Experience (Lightbox + Trip Gallery)

**Status:** Draft — preparation + implementation blueprint. **Do not start coding. Await approval.**
**Date:** 2026-05-16
**Type:** Feature — frontend UX (Phlex component + Stimulus controller + new gallery page) with a Google Stitch design pass.
**Confidence Score:** 8/10 — Every moving part has an exact in-repo precedent: `JournalEntryCard` already renders the cover + grid we hook into, `feed_entry_controller.js` is a 1:1 template for the new Stimulus controller, `audit_logs` (path `activity`) is the template for the new trip-scoped `gallery` route + policy + controller + Phlex view + action-bar link, and `image_processing`/`ruby-vips` is already in the bundle so Active Storage variants work. The two reasons it is not 9/10: (1) the lightbox is net-new interaction code (focus trap, keyboard, touch swipe, body-scroll-lock) with no existing precedent in `app/javascript/controllers/`, so it carries the most one-pass risk; (2) the overlay needs several Tailwind utility classes that are almost certainly **not** in the compiled CSS yet, so a `bin/cli app rebuild` is mandatory before the lightbox will render — easy to forget and produces a "nothing happens" symptom that masquerades as a JS bug.

---

## Table of Contents

1. [Clarifying Questions — Assumptions to Confirm](#1-clarifying-questions--assumptions-to-confirm)
2. [Problem Statement](#2-problem-statement)
3. [Goals and Non-Goals](#3-goals-and-non-goals)
4. [Codebase Context](#4-codebase-context)
5. [Architecture & Key Decisions](#5-architecture--key-decisions)
6. [UX Specification](#6-ux-specification)
7. [Accessibility Requirements](#7-accessibility-requirements)
8. [Edge Cases](#8-edge-cases)
9. [Implementation Blueprint](#9-implementation-blueprint)
10. [Task List (ordered)](#10-task-list-ordered)
11. [Testing Strategy](#11-testing-strategy)
12. [Validation Gates (Executable)](#12-validation-gates-executable)
13. [Runtime Test Checklist](#13-runtime-test-checklist)
14. [Google Stitch Plan](#14-google-stitch-plan)
15. [Documentation Updates](#15-documentation-updates)
16. [Rollback Plan](#16-rollback-plan)
17. [Out of Scope / Future Phase](#17-out-of-scope--future-phase)
18. [Reference Documentation](#18-reference-documentation)
19. [Quality Checklist](#19-quality-checklist)

---

## 1. Clarifying Questions — Assumptions to Confirm

The brief was intentionally open. These were put to the product owner and **resolved (2026-05-17)**; the PRP below reflects the resolved column.

| # | Question | **Resolution** | Consequence |
|---|----------|----------------|-------------|
| Q1 | Who can see the trip gallery? | ✅ **Anyone who can see the trip** — `TripPolicy#show?` (`superadmin \|\| member`), incl. viewers/guests who are members. Standard `403` for non-members (NOT the audit feed's 404-hide). | Gallery uses plain `authorize! @trip, to: :show?`. No bespoke policy. |
| Q2 | Lightbox library vs hand-rolled? | ✅ **Pure Stimulus — but only if it stays simple.** Target ≤ ~250 lines. **Hard ceiling:** if the controller balloons (multi-hundred-line cross-viewport edge-case handling), stop and pin a small dependency-free ESM lightbox via **importmap from a CDN** (no npm, honours the constraint) — preferred fallback **PhotoSwipe v5** (ESM, zero deps) pinned with `bin/importmap pin photoswipe --from jspm`. Decision is made *during* task 2, not deferred. | Estimated hand-rolled size ≈ 150–200 lines (focus-trap + swipe + keys + scroll-lock + wrap) — within budget, so Stimulus is the default path. The ceiling is the explicit escape hatch the owner asked for. |
| Q3 | Thumbnail strategy? | ✅ **Active Storage variants** for thumbnails (`image_processing`/`ruby-vips` bundled — `Gemfile:80`), **original** for fullscreen. Fallback to `url_for(image)` if a variant raises in dev. | Free perf, no new dependency. |
| Q4 | Gallery grouping? | ✅ **Flat grid — no per-entry sections.** One responsive masonry/grid of every trip image, newest-first. Lightbox navigates the whole flat set. Per-image **caption** (owning entry name + date) shown in the fullscreen view only, so context survives without sectioning the page. | Simpler view (no section headers/loop), simpler controller wiring. |
| Q5 | Scope of "work with Google Stitch via the MCP Server"? | ✅ **Active MCP interaction, not just a prompt file.** Request the lightbox + gallery design *through the Stitch MCP server*, apply the existing Catalyst design system to it, and use the returned design to drive the Phlex/Tailwind build. The prompt file is the input to that MCP call, the Stitch output is a build input — not merely advisory. | Adds a real design step (§14) before the Phlex view is finalised; Stitch output saved under `designs/`. |

---

## 2. Problem Statement

Images are the heart of a trip journal, but today they are nearly inert:

- `Components::JournalEntryCard` (`app/components/journal_entry_card.rb`) renders a **cover image** (`render_cover_image`, `@entry.images.first`, lines 37–49) and, inside the expandable body, a **2/3-column grid** of every attachment (`render_images`, lines 159–177). Both are plain `<img>` tags. **Clicking does nothing.** There is no fullscreen view, no next/previous, no keyboard or touch navigation.
- There is **no way to browse all of a trip's photos in one place.** A trip with 20 entries scatters its images across 20 collapsed cards.
- Nothing in `app/javascript/controllers/` handles image viewing (`grep` for `lightbox/fullscreen` → empty).

Result: the most important content in the product is the least navigable. Phase 22 makes images first-class — tap any photo to view it full-screen and swipe/arrow through the rest — and adds a per-trip gallery.

---

## 3. Goals and Non-Goals

### Goals
1. **Lightbox viewer** — clicking any journal-entry image (cover or grid) opens a full-screen overlay showing that image at full size, with prev/next navigation across **all images of that entry**. Works on desktop (click + keyboard) and mobile (tap + swipe). ESC / backdrop / close-button dismisses. Reusable Phlex component + Stimulus controller, zero npm.
2. **Trip gallery** — a new page `/trips/:id/gallery` collecting every image across the trip's journal entries in **one flat newest-first grid**, each thumbnail opening the same lightbox navigating the **entire trip image set**.
3. **Entry point** — a "Gallery" action on the trip page action bar, alongside `Edit · Members · Checklists · Exports · Activity · Delete`.
4. **Performance** — thumbnails served as resized Active Storage variants; full-size original loaded only when the lightbox opens; lightbox images lazy-decoded.
5. **A Google Stitch design, obtained and applied via the Stitch MCP server** — request the lightbox + gallery design through MCP, apply the existing Catalyst design system, drive the Phlex/Tailwind build from the returned design.

### Non-Goals (see [§17](#17-out-of-scope--future-phase))
- Editing, reordering, deleting, or captioning images from the lightbox/gallery (read-only viewing only).
- Pinch-to-zoom / pan within the fullscreen image (basic swipe-between only).
- A cross-trip / global gallery.
- Slideshow autoplay, download-all, EXIF/metadata display.
- Video or non-image attachments.
- Replacing Active Storage / SeaweedFS work (#44 is separate).

---

## 4. Codebase Context

Read these before implementing — they are the exact patterns to mirror.

| Concern | File | Why it matters |
|---------|------|----------------|
| Cover + grid render (the integration site) | `app/components/journal_entry_card.rb` (`render_cover_image` L37–49, `render_images` L159–177) | Both `<img>` blocks become lightbox triggers. The whole card already wraps a `feed-entry` Stimulus controller — nest the lightbox controller on the image-group wrapper, not the `<article>`. |
| Stimulus controller pattern | `app/javascript/controllers/feed_entry_controller.js` | Canonical structure: `static targets`, `static values`, `connect()`, action methods, `hidden` toggling, `aria-expanded`. New controller mirrors this exactly. Controllers auto-register via `app/javascript/controllers/index.js` (eager-loaded). |
| Trip-scoped sub-resource (route → controller → policy → Phlex view → action-bar link) | `audit_logs`: `config/routes.rb:50` (`resources :audit_logs, only: [:index], path: "activity"`), `app/policies/audit_log_policy.rb`, the "Activity" link in `app/views/trips/show.rb` `render_action_bar`. | 1:1 template for `gallery`. Gallery uses a member `get :gallery` route → `TripsController#gallery` (no model of its own, unlike audit_logs which has a real model). |
| Trip show view + action bar | `app/views/trips/show.rb` (`render_action_bar` ~L82–125, `render_journal_entries` ~L190) | Where the "Gallery" link goes; the gallery view subclasses `Views::Base` just like `Views::Trips::Show`. |
| Eager-loading attachments (avoid N+1) | `app/controllers/trips_controller.rb` `show` (`@trip.journal_entries...includes({ images_attachments: :blob })`, ~L20–28) | The gallery action must eager-load identically or it N+1s the gallery grid. |
| Phlex base + design tokens | `app/views/base.rb`, `app/components/base.rb`, `ui_library/README.md`, `ui_library/*.yml` (28 entries) | Use `ha-card`, `ha-overline`, `ha-button*`, `--ha-*` tokens. Auto-escaping is on; no `unsafe_raw`/`raw` needed for this feature. |
| Phlex helpers in components | `JournalEntryCard` includes `LinkTo`, `ButtonTo`, `DOMID`; calls `view_context.url_for(...)`, `view_context.allowed_to?`. | Variants: `view_context.url_for(image.variant(...))`. The view needs `Phlex::Rails::Helpers::Routes` (or `view_context.*_path`) for links. |
| Image variants available | `Gemfile:80` `image_processing ~> 1.2`; `Gemfile.lock` `ruby-vips 2.3.0`, `mini_magick 5.3.1`. | `image.variant(resize_to_limit: [W, H])` is safe to use. Dev uses the disk service. |

### Current image render (the code being replaced/wrapped)

```ruby
# app/components/journal_entry_card.rb — render_images (L159–177), TODAY
def render_images
  div(class: "grid grid-cols-2 gap-3 mb-6 md:grid-cols-3") do
    @entry.images.each_with_index do |image, idx|
      div(class: "group/photo overflow-hidden rounded-xl") do
        img(src: view_context.url_for(image),
            class: "h-full w-full object-cover ...",
            style: "aspect-ratio: 4/3;",
            alt: "#{@entry.name} — photo #{idx + 1}",
            loading: "lazy")
      end
    end
  end
end
```

---

## 5. Architecture & Key Decisions

### 5.1 `Components::Lightbox` — a reusable, self-contained image group

A single Phlex component that takes an **ordered list of images** + alt text and renders:

1. The **trigger thumbnails** (its own grid), each a `<button>` carrying `data-lightbox-target="trigger"` + `data-action="click->lightbox#open"` + `data-lightbox-index-param="N"`.
2. One **overlay** (`<div role="dialog" aria-modal="true" hidden>`) containing: a large `<img data-lightbox-target="image">`, prev/next `<button>`s, a close `<button>`, and a counter (`3 / 12`).
3. The full-size original URLs are emitted in a `data-lightbox-urls-value` JSON array (string array) on the controller root; thumbnails use variant URLs.

The root element carries `data-controller="lightbox"`. **One instance per image group** — so each journal-entry card gets its own Lightbox over that entry's images, and the gallery gets one Lightbox over the whole trip set. This avoids any global singleton/coordination problem and keeps Stimulus scoping trivial (mirrors how every card independently runs its own `feed-entry` controller today).

Component API:

```ruby
Components::Lightbox.new(
  images: <Array of { thumb_url:, full_url:, alt: }>,  # ordered
  columns: 3,                                          # grid cols on md+
  caption_for: ->(i) { ... } | nil                     # optional per-image label (gallery uses entry title)
)
```

`JournalEntryCard#render_images` and `#render_cover_image` are refactored so the **cover is index 0 and also the first grid item** (today `render_cover_image` shows `images.first` and `render_images` shows all images including the first — keep that; the cover trigger opens the lightbox at index 0). The card builds the `images:` array once and passes it both to the cover trigger and the grid.

> **Decision:** Cover image becomes a lightbox trigger for index 0; the in-body grid becomes the trigger set for indices 0..n. The Lightbox component owns the overlay markup; the card owns where the grid sits. Simplest split that avoids duplicating overlay markup per card while keeping per-group scoping.

### 5.2 `lightbox_controller.js` — Stimulus, no dependencies

Mirror `feed_entry_controller.js` structure exactly.

```js
// app/javascript/controllers/lightbox_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "image", "counter", "trigger"]
  static values  = { urls: Array, index: Number, captions: Array }

  connect() {
    this.indexValue = 0
    this.overlayTarget.hidden = true
    this._onKey = this.onKey.bind(this)
  }

  disconnect() {
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
  }

  open(event) {
    this.indexValue = Number(event.params.index ?? 0)
    this.render()
    this.overlayTarget.hidden = false
    this.lock()                       // body scroll lock
    document.addEventListener("keydown", this._onKey)
    this._lastFocus = document.activeElement
    this.overlayTarget.querySelector("[data-lightbox-close]").focus()
  }

  close() {
    this.overlayTarget.hidden = true
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
    this._lastFocus?.focus()
  }

  next() { this.go(1) }
  prev() { this.go(-1) }

  go(delta) {
    const n = this.urlsValue.length
    this.indexValue = (this.indexValue + delta + n) % n   // wrap
    this.render()
  }

  render() {
    const i = this.indexValue
    this.imageTarget.src = this.urlsValue[i]
    if (this.hasCounterTarget) this.counterTarget.textContent = `${i + 1} / ${this.urlsValue.length}`
    if (this.hasCaptionsValue && this.captionsValue.length) { /* set caption */ }
  }

  onKey(e) {
    if (e.key === "Escape") this.close()
    if (e.key === "ArrowRight") this.next()
    if (e.key === "ArrowLeft")  this.prev()
    if (e.key === "Tab") this.trapFocus(e)   // keep focus inside overlay
  }

  // touch swipe
  touchStart(e) { this._x = e.changedTouches[0].clientX }
  touchEnd(e)   {
    const dx = e.changedTouches[0].clientX - this._x
    if (Math.abs(dx) > 50) (dx < 0 ? this.next() : this.prev())
  }

  lock()   { document.body.style.overflow = "hidden" }
  unlock() { document.body.style.overflow = "" }
  trapFocus(e) { /* cycle focus among close/prev/next */ }
}
```

Gotchas baked in: wrap-around navigation, body scroll lock + restore on disconnect (Turbo navigation away), focus save/restore + focus trap, ESC/arrow keys, 50px swipe threshold, `disconnect()` cleanup so a Turbo visit can't leave a locked body or a dangling keydown listener.

### 5.3 Gallery route / controller / view

Mirror `audit_logs`, but as a **member route** (no model):

```ruby
# config/routes.rb — inside `resources :trips do ... member do`
member do
  patch :transition
  get  :gallery            # NEW → /trips/:id/gallery
end
```

```ruby
# app/controllers/trips_controller.rb — NEW action
def gallery
  @trip = Trip.find(params[:id])
  authorize! @trip, to: :show?                   # TripPolicy#show? (Q1)
  @journal_entries = @trip.journal_entries
                          .reverse_chronological
                          .includes({ images_attachments: :blob }, :rich_text_body)
  render Views::Trips::Gallery.new(trip: @trip, journal_entries: @journal_entries)
end
```

`Views::Trips::Gallery` subclasses `Views::Base`, renders a header (overline = trip name, title = "Gallery", "Back to trip" button) and **one flat `Components::Lightbox`** whose `images:` is the flattened newest-first list across all entries (no per-entry sections). `caption_for` returns the owning entry's title + date so context survives in the fullscreen view. Entries with no attachments contribute nothing; a trip with zero images renders an empty state (simple `ha-card` message).

Action-bar link in `app/views/trips/show.rb#render_action_bar` (gated by `allowed_to?(:show?, @trip)` — effectively always true for someone already on the page, but keep the guard for consistency with siblings):

```ruby
link_to("Gallery", view_context.gallery_trip_path(@trip),
        class: "ha-button ha-button-secondary")
```

### 5.4 Why these decisions

- **Per-group Lightbox instances, not a global one:** matches the existing "every card runs its own controller" model (`feed-entry`), eliminates cross-instance coordination, and means the gallery and a card never fight over one overlay.
- **Member `get :gallery` vs nested resource:** the gallery has no persistent model (unlike `audit_logs` which is a real table). A member action on `trips` is the lightest correct mapping and keeps the URL `/trips/:id/gallery`.
- **Variants for thumbs, original for fullscreen:** `image_processing` is already bundled; this is free perf with no new dependency. Fallback to `url_for(image)` if a variant raises in dev.
- **No npm lightbox lib:** honours the hard "importmap only, no npm" constraint in PROJECT SUMMARY.

---

## 6. UX Specification

**Lightbox (both contexts):**
- Trigger: thumbnails get `cursor-zoom-in`, a subtle hover scale (reuse existing `group-hover/photo:scale-110`), and are real `<button>`s (keyboard-focusable, Enter/Space open).
- Overlay: full-viewport `fixed inset-0 z-50`, dark scrim (`bg-black/90`), centered image (`max-h-[90vh] max-w-[90vw] object-contain`).
- Controls: large prev/next chevrons (hidden when only 1 image), a close `✕` top-right, a `current / total` counter, optional caption (gallery only) bottom-center.
- Dismiss: ESC, backdrop click, close button. Image click does **not** dismiss (reserved for future zoom).
- Navigation: arrow keys, on-screen chevrons, horizontal swipe (mobile). Wraps at both ends.
- Open/close are instant (no heavy animation needed for one-pass; a fade via existing `transition`/`duration-*` utilities is a nice-to-have).

**Gallery page:**
- Header: `ha-overline` = trip name (upper-cased like other screens), `h1`/`h2` "Gallery", right-side "Back to trip" `ha-button-secondary`.
- Body: **one flat responsive grid** (`grid-cols-2 sm:grid-cols-3 lg:grid-cols-4`) of variant thumbnails, newest-first, no section headers. Each thumb opens the lightbox at its index over the whole trip set; the fullscreen caption names the owning entry + date.
- Empty state: friendly `ha-card` "No photos yet — add images to your journal entries to see them here."

---

## 7. Accessibility Requirements

`/ux-review` and `/ui-polish` will check these — build them in from the start:

- Triggers are `<button type="button">` with descriptive `aria-label` (e.g. `"View photo 2 of 7 — {entry name}"`).
- Overlay: `role="dialog"`, `aria-modal="true"`, `aria-label="Image viewer"`. `hidden` attribute toggled (not just CSS) so it's removed from the a11y tree when closed.
- Focus moves to the close button on open; focus is trapped within the overlay (Tab cycles close → prev → next); focus returns to the triggering thumbnail on close.
- Prev/next/close buttons have `aria-label`s; counter is `aria-live="polite"` so screen readers announce position changes.
- Keyboard parity with mouse: ESC, ←/→, Tab trap.
- Respect `prefers-reduced-motion` for any transition (no essential motion).

---

## 8. Edge Cases

| Case | Expected behaviour |
|------|--------------------|
| Entry with 0 images | No cover, no lightbox trigger (current `if @entry.images.attached?` guard preserved). |
| Entry with exactly 1 image | Lightbox opens; prev/next chevrons hidden; counter shows `1 / 1`; swipe/arrow no-op (wrap of length 1). |
| Trip with 0 images at all | Gallery page renders empty state, no overlay rendered. |
| Very large originals | Thumbnails are variants (small); fullscreen `<img>` is `loading`/decoding deferred until `open()`; `object-contain` prevents overflow. |
| Variant generation fails in dev (disk service) | Component rescues and falls back to `url_for(image)` for that thumb (no 500). |
| Turbo navigation while overlay open | `disconnect()` unlocks body + removes keydown listener (no stuck scroll-lock). |
| Non-image attachment somehow attached | Out of scope — only `has_many_attached :images`; assume images. Guard with `image?` content-type check; skip non-images. |
| Many entries in gallery (N+1) | Controller eager-loads `images_attachments: :blob` (mirrors `show`). |
| Auth: viewer/guest opens `/trips/:id/gallery` for a trip they're a member of | Allowed (Q1, `TripPolicy#show?`). Non-member → existing `ActionPolicy::Unauthorized → 403` (standard app behaviour; gallery is **not** hidden like the audit feed). |

---

## 9. Implementation Blueprint

Pseudocode / order of construction:

```
0. Stitch MCP design flow (§14)        # generate+apply Gallery & Lightbox design → designs/  (drives 2/6 layout)
1. lightbox_controller.js              # Stimulus — no deps; structure ≅ feed_entry_controller.js; ≤~250 lines or pivot to PhotoSwipe-via-importmap
2. Components::Lightbox (Phlex)        # triggers grid + overlay; builds urls JSON
   - helper: variant_url(image)  -> view_context.url_for(image.variant(resize_to_limit:[800,800])) rescue url_for(image)
   - helper: full_url(image)     -> view_context.url_for(image)
3. Refactor JournalEntryCard
   - build images = @entry.images.map -> { thumb_url, full_url, alt }
   - render_cover_image: wrap <img> in a <button> opening Lightbox at index 0  (reuse component or a thin trigger)
   - render_images: replace hand-rolled grid with render Components::Lightbox.new(images:, columns: 3)
4. Route: member get :gallery
5. TripsController#gallery  + authorize! @trip, to: :show?  + eager load
6. Views::Trips::Gallery (Phlex, < Views::Base) — implements the applied Stitch design
   - flatten images across reverse_chronological entries, preserving owning entry for caption
   - one flat Components::Lightbox over the whole set (no section headers)
   - empty state when no images
7. "Gallery" link in Views::Trips::Show#render_action_bar
8. ui_library/lightbox.yml + ui_library/trips_gallery.yml  (+ regenerate index per ui-designer convention)
9. Tests: component spec, request spec (gallery 200/403, N+1), system spec (open/next/prev/esc)
10. bin/cli app rebuild  (Tailwind JIT — overlay classes)  → runtime checklist
```

Error-handling strategy: variant generation wrapped in `rescue` → original URL fallback (never 500 a card or the gallery over a thumbnail). Stimulus `disconnect()` is the safety net for body-scroll-lock and listener leaks. Controller uses standard `authorize!`; non-members get the conventional 403 (no special 404 — distinct from the audit feed by design, Q1).

---

## 10. Task List (ordered)

Per project workflow (`/execution-plan`): **GitHub issue first** (label `feature`), Kanban Backlog → Ready → In Progress, branch `feature/phase-22-image-experience`, **atomic commits** (one concern each), live `/product-review` before PR, then PR + In Review.

1. `feat(issue)`: open GitHub issue + Kanban move (workflow gate, no code).
2. `docs: Phase 22 Stitch brief` + **run the Stitch MCP design flow** (§14) — generate Gallery + Lightbox screens, apply the Catalyst design system, save under `designs/`. **Design step — precedes the component/view build so they implement the applied design.**
3. `feat(js): add lightbox Stimulus controller` — `app/javascript/controllers/lightbox_controller.js`. **Apply the Q2 complexity ceiling here:** if it exceeds ~250 lines, switch to PhotoSwipe v5 pinned via importmap (no npm) and adjust this commit.
4. `feat(ui): add Components::Lightbox` — Phlex component (triggers + overlay) matching the Stitch design, variant/full URL helpers.
5. `refactor(ui): wire JournalEntryCard cover + grid into Lightbox` — replace `render_images`, make cover index 0.
6. `feat(routes): add trip gallery member route`.
7. `feat(gallery): TripsController#gallery + authorization + eager load`.
8. `feat(ui): add Views::Trips::Gallery page` — flat grid, matching the applied Stitch design.
9. `feat(ui): add Gallery link to trip action bar`.
10. `docs(ui_library): register lightbox + gallery components` (+ regenerate index).
11. `test: lightbox component + gallery request + lightbox system specs`.
12. Runtime: `bin/cli app rebuild && app restart && mail start` → full [§13](#13-runtime-test-checklist) checklist.
13. `/security-review` → `/qa-review` → `/ux-review` → `/ui-polish` → remediate via `/qa-remediation` → PR.

---

## 11. Testing Strategy

| Level | What | Where |
|-------|------|-------|
| Component (RSpec + Capybara matchers on rendered Phlex) | `Components::Lightbox` renders N triggers, an overlay with `role=dialog hidden`, correct `data-lightbox-urls-value` JSON, prev/next hidden when 1 image. | `spec/components/lightbox_spec.rb` (mirror existing component specs). |
| Request | `GET /trips/:id/gallery` → 200 for member (incl. viewer), 403 for non-member, renders one flat grid with a thumbnail per attachment across all entries, empty state when none; assert **no N+1** (`includes`). | `spec/requests/trips/gallery_spec.rb`. |
| System (JS, headless) | Open trip → click cover → overlay visible → ArrowRight advances counter → ESC closes → focus returns. Gallery → click thumb in section 2 → correct image shown → next wraps. | `spec/system/lightbox_spec.rb` (Capybara, follow existing system-test setup). |
| Factories | Use `FactoryBot.create(:journal_entry, trip:)` and attach images via fixture (`Rails.root.join("spec/fixtures/files/...")`). Never raw `create!` (CLAUDE.md runtime note). |

Real-journey requirement (PROJECT SUMMARY): a page rendering ≠ feature working — system test must actually open, navigate, and close the lightbox, not just assert the trigger exists.

---

## 12. Validation Gates (Executable)

All Ruby commands run under the project Ruby (`mise x --`); the harness ruby-version-manager skill provides the activation prefix — chain it.

```bash
# Lint (autocorrect then verify)
bundle exec rake project:fix-lint
bundle exec rake project:lint

# Unit + component + request
bundle exec rake project:tests

# System (JS lightbox, headless)
bundle exec rake project:system-tests
```

Overcommit pre-commit (RuboCop, trailing whitespace, no FIXME, capitalised subjects, no trailing period, body width) must pass. If a hook is a genuine false positive: `SKIP=<HookName> git commit ...` + footnote in the body explaining the skip. Never `OVERCOMMIT_DISABLE=1`. No `[skip ci]` (UI-only paths already in `paths-ignore`; runtime code here is not).

**Tailwind JIT gate (load-bearing):** the overlay introduces utility classes (`z-50`, `bg-black/90`, `max-h-[90vh]`, `max-w-[90vw]`, `object-contain`, `cursor-zoom-in`, possibly `inset-0` combos) that are likely **not** in the compiled CSS. After implementation **`bin/cli app rebuild` is mandatory** or the lightbox renders unstyled/invisible and looks like a JS failure. Prefer classes already present where possible; the rebuild is non-negotiable for the genuinely new ones.

---

## 13. Runtime Test Checklist

Per CLAUDE.md §5 — performed live with `agent-browser` after rebuild, before PR:

- [ ] `bin/cli app rebuild` succeeds
- [ ] `bin/cli app restart` health check passes
- [ ] `bin/cli mail start` running
- [ ] Trip show page renders; cover image now shows `cursor-zoom-in`
- [ ] Click cover → fullscreen overlay opens at the correct image
- [ ] Expand an entry → grid thumbnails open lightbox at their index
- [ ] Next/Prev (on-screen + ←/→ keys) cycle and wrap; counter updates
- [ ] ESC and backdrop click close; focus returns to the thumbnail
- [ ] Mobile viewport (agent-browser device emulation): tap opens, horizontal swipe navigates
- [ ] Single-image entry: no chevrons, counter `1 / 1`
- [ ] "Gallery" link appears in the trip action bar
- [ ] `/trips/:id/gallery` renders grouped sections; thumbnails open the trip-wide lightbox; navigation crosses sections
- [ ] Trip with no images → gallery empty state (no error)
- [ ] Non-member → 403 on the gallery URL; member viewer → 200
- [ ] Dark-mode: overlay scrim + controls legible in both themes
- [ ] No console/runtime errors on any touched page

---

## 14. Google Stitch Plan

**Per Q5 this is an active MCP interaction whose output drives the build — not an advisory prompt file.** It runs as a real design step **before** the Phlex view (task 7) is finalised.

1. Write `prompts/Phase 22 - Image Experience - Google Stitch Prompt.md` as the **input brief** for the MCP call. Same preamble as `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md`: **the Catalyst design system is already established in Stitch — do not invent colours, type, spacing; apply the existing system; match current screens.** The brief defines structure, placement, content, states, interactions.
2. Brief covers two surfaces:
   - **Lightbox overlay** — scrim, centered image, prev/next, close, counter, caption; net-new (no sibling) so describe every state (single vs many images, open/closed, mobile swipe affordance, reduced-motion).
   - **Trip Gallery page** — lives in the existing app shell (do not redesign the shell); entry point = "Gallery" action on the trip action bar (same treatment as `Activity`); **one flat thumbnail grid** (no per-entry sections, per Q4); empty state.
3. **Run the Stitch MCP flow (active, this is the design step):**
   `mcp__stitch__list_design_systems` → confirm the Catalyst system exists (capture its id); `mcp__stitch__list_projects` / `mcp__stitch__get_project` → locate/confirm the Catalyst project; `mcp__stitch__generate_screen_from_text` with the brief from step 1 to generate the **Gallery** screen and a **Lightbox** screen (or `mcp__stitch__edit_screens` if iterating an existing screen); `mcp__stitch__apply_design_system` with the captured Catalyst design-system id so the output uses the established tokens; `mcp__stitch__get_screen` to pull the final design.
4. Save the returned Stitch design under `designs/` (sibling of `designs/stitch_create_edit_entry`, `designs/catalyst_glass`), e.g. `designs/stitch_trip_gallery`.
5. **The Stitch output is a build input:** the Phlex `Views::Trips::Gallery` + `Components::Lightbox` layout/structure is implemented to match the applied Stitch design (mapped onto existing `--ha-*` tokens and `ha-*` class families — never raw Stitch CSS). If the design and the established token system conflict, the token system wins and the divergence is noted in `prompts/Phase 22 - Steps.md`.

---

## 15. Documentation Updates

- `ui_library/lightbox.yml`, `ui_library/trips_gallery.yml` — register the new component + page (library_source likely `application_ui/overlays/*` for the modal; document tokens + Tailwind classes). Regenerate the `ui_library` index per the `ui-designer` convention (recent commits show the index is regenerated explicitly).
- `prompts/Phase 22 - Steps.md` — audit trail, created during execution (not now).
- No `CLAUDE.md` change required (no new architectural rule introduced; lightbox is conventional Stimulus/Phlex). If the per-group-Lightbox pattern proves reusable elsewhere, add a one-line note to the planning conventions in a later phase.

---

## 16. Rollback Plan

Purely additive and reversible:
- Revert the `JournalEntryCard` refactor commit → cover/grid return to plain `<img>` (no data loss; images untouched).
- Remove the `gallery` route + action + view + action-bar link → 404 on the URL; no schema/migration involved.
- Delete `lightbox_controller.js` + `Components::Lightbox`.
No DB migration, no Active Storage data change, no event/subscriber change → zero-risk rollback.

---

## 17. Out of Scope / Future Phase

- In-lightbox pinch-zoom / pan, slideshow autoplay, download, EXIF/metadata.
- Image management (reorder, delete, set-cover, caption) from gallery/lightbox.
- Cross-trip / global gallery; gallery filtering/search.
- Video & non-image attachments.
- CDN/SeaweedFS variant pipeline tuning (#44).
- Sharing a deep link to a specific image (URL-addressable lightbox state).

---

## 18. Reference Documentation

- Stimulus handbook (controllers, targets, values, lifecycle): https://stimulus.hotwired.dev/handbook/introduction
- Stimulus values & params (`event.params`): https://stimulus.hotwired.dev/reference/actions
- Active Storage variants (`variant`, `resize_to_limit`, `image_processing`): https://guides.rubyonrails.org/active_storage_overview.html#transforming-images
- `image_processing` gem (libvips/MiniMagick): https://github.com/janko/image_processing
- WAI-ARIA Authoring Practices — Dialog (Modal) pattern (focus management, keyboard): https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- Phlex views: https://www.phlex.fun/
- Tailwind CSS docs (utilities used: z-index, object-fit, max-h/max-w arbitrary values): https://tailwindcss.com/docs
- In-repo precedents (read directly): `app/javascript/controllers/feed_entry_controller.js`, `app/policies/audit_log_policy.rb`, `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md`, `app/components/journal_entry_card.rb`.

---

## 19. Quality Checklist

- [x] All necessary context included (exact files, line numbers, current code shown)
- [x] Validation gates are executable by the AI (`rake project:*`, overcommit, rebuild)
- [x] References existing patterns (`feed_entry_controller`, `audit_logs`, `JournalEntryCard`, `ui_library`)
- [x] Clear implementation path (ordered task list + pseudocode blueprint)
- [x] Error handling documented (variant fallback, Stimulus disconnect cleanup, auth behaviour)
- [x] Accessibility specified up front (dialog pattern, focus trap, keyboard parity)
- [x] Open assumptions surfaced for approval (§1 Q1–Q5)

**Confidence: 8/10** for one-pass success. Risk concentrated in the net-new lightbox interaction JS (no in-repo precedent for focus-trap/swipe/scroll-lock) and the easy-to-forget mandatory Tailwind rebuild; everything else has an exact template to copy.

---

> **STOP — awaiting go-ahead.** §1 Q1–Q5 are now resolved (2026-05-17) and the PRP reflects them. No issue, no branch, no code — and the Stitch MCP design flow (task 2 / §14) — until the product owner says "begin".
