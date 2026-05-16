# Google Stitch Prompt — Trip Activity Feed (Audit Journal)

> **Scope note.** The Catalyst design system is already established in Stitch.
> **Do not invent colours, typography, spacing, or component styling** — apply
> the existing design system and match the look of the current app screens
> (the Notifications feed and the trip "Feed Wall" are the closest siblings).
> This brief defines only **structure, placement, content, states, and
> interactions** — the *what* and *where*, not the *how it looks*.

## Objective

Design one new internal page: the **Trip Activity Feed** — a read-only,
chronological log of every action taken on a single trip.

## Placement & navigation

- Lives inside the **existing authenticated app shell** (the standard sidebar +
  main content area used by every other page). Do **not** redesign the shell.
- It is a **per-trip** page. Entry point: a new **"Activity"** action on the
  trip page's existing action bar, alongside `Edit · Members · Checklists ·
  Exports · Delete · Back to trips`. Use the same button treatment as those.
- Route: `/trips/:id/activity`. Internal-only; assume the viewer is authorised
  (no permission/teaser state needed — unauthorised users never reach it).

## Page structure

1. **Page header**
   - Overline: the trip name (e.g. `ICELAND ROAD TRIP`).
   - Title: `Activity`.
   - Header actions (right side): a **"Show low-signal"** toggle and a
     **"Back to trip"** button.

2. **Feed body** — a vertical, newest-first list, **grouped by day**:
   - Each group starts with a **day divider** label: `Today`, `Yesterday`,
     or an absolute date (`15 May 2026`).
   - Under each divider, the activity **rows** for that day.
   - New rows can arrive **live at the top of "Today"** without a reload —
     show where an incoming row inserts.

3. **Activity row** (the core component) carries:
   - **Actor avatar** — initials.
   - **Summary line** — one sentence, e.g.
     `Joel Azemar updated trip "Iceland Road Trip"`.
   - **Diff block (optional)** — only for edits: one line per changed field,
     `Field: old value → new value` (old value visually struck/retired, new
     value emphasised). Show 1–3 fields.
   - **State-change variant (optional)** — a `From → To` pair of small chips
     (e.g. `Planning → Started`).
   - **Relative timestamp** — e.g. `less than a minute ago`.
   - **Source badge (optional)** — `Agent`, `Telegram`, or `System`; **no
     badge** for ordinary user (web) actions.
   - **Low-signal rows** (reactions, checklist ticks) are visually
     **de-emphasised** and **hidden by default** — revealed only when the
     "Show low-signal" toggle is on, in place among the other rows.
   - Rows are **read-only**: no edit/delete/menu affordances.

4. **"Load older"** — a control at the foot of the list that appends the next
   older batch (older day groups appear below).

5. **Empty state** — when the trip has no activity: an icon, a short title
   (`No activity yet`), and one line of helper text.

## Screens / states to produce

1. **Populated feed** — at least two day groups; include a normal action row,
   an **edit row with a diff block**, a **state-change row**, and one row with
   a **source badge** (`Agent`).
2. **Empty state**.
3. **Low-signal toggle ON** — the dimmed reaction/checklist rows now visible
   inline among normal rows.
4. **Live insert** — a new row appearing at the top of the "Today" group
   (illustrate the transition/entry point).
5. **Mobile** — the same structure in the app's single-column mobile layout
   (use the existing responsive shell; do not restyle).

## Interactions to convey

- Toggling **"Show low-signal"** reveals/hides the de-emphasised rows in place.
- **"Load older"** appends older content below without leaving the page.
- New rows **stream in at the top** in real time (no reload).

## Realistic sample content

- `Joel Azemar created trip "Iceland Road Trip"` — Today
- `Joel Azemar updated trip "Iceland Road Trip"` — diff: `Description: "Ring
  road adventure…" → "Updated route via the south coast"` — Today
- `Joel Azemar changed the state of trip "Iceland Road Trip"` — `Planning →
  Started` — Today
- `Marée (agent) created journal entry "Visited Mont Saint-Michel"` — `Agent`
  badge — Yesterday
- `Alex Doe removed Sam Lee from the trip` — Yesterday
- *(low-signal, hidden by default)* `Marée reacted to a journal entry`

## Explicitly out of scope

- **No visual design system work** — colours, fonts, spacing, shadows,
  elevation, dark mode: all inherited from the established Stitch design
  system. Don't define or alter them.
- No **search** or **filter** UI (future phase).
- No **app-wide / admin** activity console (future phase) — this is the
  single-trip feed only.
- No **edit/delete** affordances on rows — the log is append-only.
- No **auth/login** event rows (future phase).
- Do **not** redesign the sidebar, top bar, or trip page — only add the
  "Activity" entry point and the new page.
