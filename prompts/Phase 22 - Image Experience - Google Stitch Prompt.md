# Google Stitch Prompt — Image-Centric Experience (Lightbox + Trip Gallery)

> **Scope note.** The Catalyst design system is already established in Stitch.
> **Do not invent colours, typography, spacing, or component styling** — apply
> the existing design system and match the look of the current app screens
> (the trip "Feed Wall" / journal entry card and the Trip Activity Feed are the
> closest siblings). This brief defines only **structure, placement, content,
> states, and interactions** — the *what* and *where*, not the *how it looks*.

## Objective

Design two connected surfaces that make trip photos first-class:

1. An **image Lightbox** — a full-screen overlay to view any journal photo at
   full size and move through the rest.
2. A **Trip Gallery** page — every photo across a trip's journal entries in one
   flat grid, each opening the Lightbox over the whole trip set.

## Placement & navigation

- Both live inside the **existing authenticated app shell** (standard sidebar +
  main content). Do **not** redesign the shell.
- **Lightbox** is invoked from existing surfaces: the journal-entry **cover
  image** and the in-entry **photo grid** on the trip page, and every thumbnail
  on the Gallery page. It is an **overlay above the whole app**, not a route.
- **Gallery** is a **per-trip** page. Entry point: a new **"Gallery"** action on
  the trip page's existing action bar, alongside `Edit · Members · Checklists ·
  Exports · Activity · Delete · Back to trips`. Same button treatment as those.
- Gallery route: `/trips/:id/gallery`. Visible to anyone who can see the trip
  (incl. viewers) — assume the viewer is authorised.

## Lightbox structure

1. **Scrim** — full-viewport dark backdrop over the dimmed app. Clicking the
   scrim closes the Lightbox.
2. **Stage** — the current photo, centered, scaled to fit the viewport without
   cropping (never larger than its natural size; portrait and landscape both
   fully visible).
3. **Previous / Next controls** — large, edge-anchored, easy to hit on touch.
   **Hidden when there is only one photo.**
4. **Close control** — top-right `✕`.
5. **Counter** — `current / total` (e.g. `3 / 12`), unobtrusive.
6. **Caption (Gallery context only)** — bottom-center: the owning entry's title
   + date (e.g. `Visited Mont Saint-Michel · 14 May 2026`). **No caption** when
   opened from within a single journal entry (context is already on screen).

## Gallery page structure

1. **Page header**
   - Overline: the trip name (e.g. `ICELAND ROAD TRIP`).
   - Title: `Gallery`.
   - Header action (right side): a **"Back to trip"** button.
2. **Photo grid** — **one flat, newest-first responsive grid** of square-cropped
   thumbnails. **No per-entry sections, no section headers.** Dense on desktop,
   2-up on mobile. Every thumbnail is a button that opens the Lightbox at its
   position over the **entire trip photo set**.
3. **Empty state** — when the trip has no photos: an icon, a short title
   (`No photos yet`), and one line of helper text (`Add images to your journal
   entries to see them here`).

## Screens / states to produce

1. **Lightbox — many photos** — a mid-set photo with visible Prev/Next, counter
   `4 / 9`, close control; opened from the Gallery (caption shown).
2. **Lightbox — single photo** — Prev/Next **absent**, counter `1 / 1`.
3. **Lightbox — from a journal entry** — same overlay, **no caption**.
4. **Gallery — populated** — flat thumbnail grid, header with "Back to trip".
5. **Gallery — empty state**.
6. **Mobile** — Gallery grid in the single-column shell, and the Lightbox on a
   phone with a **horizontal swipe** affordance for next/previous (use the
   existing responsive shell; do not restyle).

## Interactions to convey

- Tapping/clicking any thumbnail or cover photo **opens the Lightbox** at that
  photo.
- **Prev/Next**, **arrow keys**, and **horizontal swipe** move through the set;
  navigation **wraps** at both ends.
- **Esc**, the close control, or a **scrim click** dismisses the Lightbox;
  focus returns to the thumbnail that opened it.
- Opening the Lightbox **locks the page behind it** (no background scroll).

## Realistic sample content

- Gallery header: `ICELAND ROAD TRIP` / `Gallery`
- Thumbnails drawn from entries like `Visited Mont Saint-Michel`,
  `Black sand beach at Vík`, `Glacier hike` — newest first, mixed
  portrait/landscape.
- Lightbox caption (Gallery): `Black sand beach at Vík · 15 May 2026`
- Counter: `4 / 9`

## Explicitly out of scope

- **No visual design system work** — colours, fonts, spacing, shadows,
  elevation, dark mode: all inherited from the established Stitch design system.
  Don't define or alter them.
- No **pinch-zoom / pan** inside the stage, no **slideshow autoplay**, no
  **download** or **share** controls, no EXIF/metadata panel.
- No **image management** (reorder, delete, set-cover, caption editing) from the
  Gallery or Lightbox — strictly read-only viewing.
- No **per-entry sections** on the Gallery — it is one flat grid.
- No **cross-trip / global** gallery.
- Do **not** redesign the sidebar, top bar, or trip page — only add the
  "Gallery" entry point, the Gallery page, and the Lightbox overlay.
