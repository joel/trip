# Google Stitch Prompt — Trip Activity (Audit Journal)

## App Context
Catalyst is a collaborative trip-planning web app (desktop-first, fully responsive,
Material 3 expressive language). It already has a "Feed Wall" of journal-entry cards
and a Notification Center. This screen is the **Trip Activity** journal: an append-only,
chronological audit feed of every action taken on a single trip, visible only to trip
contributors and superadmins. Reuse the existing Catalyst M3 design system and the
Feed Wall's visual language exactly — do NOT invent a new palette.

## Colour System (use the existing `--ha-*` CSS custom properties)
### Light mode
- Background: `--ha-bg` (app canvas)
- Card: `--ha-surface-low` rounded-2xl, soft shadow
- Surface variant / row hover: `--ha-surface-container`
- Primary / links / active: `--ha-primary`
- Primary container (accent wash): `--ha-primary-container` at 10% opacity
- Text: `--ha-text`; Muted/metadata: `--ha-on-surface-variant`, `--ha-muted`
- Danger (removed values, delete actions): `--ha-danger`
### Dark mode
- Mirror via the `.dark` token block already defined in
  `app/assets/tailwind/application.css` (glass sidebar, blurred surfaces). Dark variant required.

## Typography
- Headline font = the existing Catalyst headline utility (`font-headline`)
- Page title "Activity": text-4xl md:text-5xl, bold, tight tracking
- Section overline (trip name): `ha-overline`
- Day divider label ("Today", "Yesterday", "15 May 2026"): text-sm, semibold,
  `--ha-on-surface-variant`
- Summary line: text-sm, regular, `--ha-text`
- Timestamp + source badge: text-[11px], `--ha-muted`

## Component Patterns
- Audit row card: rounded-2xl, p-4, flex, gap-4; hover lifts to
  `--ha-surface-container`; fade-in on insert (motion-safe)
- Actor avatar: 40px rounded-2xl, `ha-gradient-aura` initials (same as Sidebar avatar)
- Source badge chip: tiny pill — "Agent" / "Telegram" / "System" (none for web),
  `--ha-primary` on `--ha-primary`/10
- Diff block: field label (semibold), old value struck-through in `--ha-danger`,
  an arrow, new value in `--ha-primary`; rich-text shows a neutral "body changed" chip
- State-change pill pair: "Planning" → "Started" rounded chips with an arrow
- Low-signal rows: dimmed (opacity-60, full opacity on hover)
- Low-signal toggle + "Back to trip" as `ha-button ha-button-secondary` in the header
- "Load older" ghost button centred at the foot of the list
- Empty state: clock icon + "No activity yet" (mirror Notifications empty state)

## Design Request: Trip Activity (4 screens)
### Screen 1 — Trip Activity, Desktop, Light
Two-column app shell (existing glass Sidebar + main). Main: PageHeader with the
trip name as overline and "Activity" as title; "Show low-signal" + "Back to trip"
buttons on the right. Below, day groups: divider label, then a column of rows.
Sample rows (realistic data):
- "Marée (agent) created journal entry 'Visited Mont Saint-Michel'" — Agent badge — 2 min ago
- "Joel updated trip — Name: 'Iceland' → 'Norway'" with the diff block — 1 h ago
- "Joel changed the state of trip 'Norway' — Planning → Started" (pill pair) — 3 h ago
- "Alex removed Sam from the trip" — `--ha-danger` accent — Yesterday
- dimmed low-signal: "Marée reacted" (hidden until the toggle is on)
### Screen 2 — Trip Activity, Desktop, Dark (same content, dark tokens)
### Screen 3 — Trip Activity, Mobile (single column, Sidebar → bottom nav;
  cards full-width, day divider sticky on scroll)
### Screen 4 — States: (a) empty state ("No activity yet"); (b) a row with a
  multi-field diff block expanded; (c) the low-signal toggle ON revealing the
  dimmed reaction rows in place.

## Interaction Patterns to Visualise
1. A new row fades/slides in at the top of "Today" in real time (no reload).
2. Toggling "Show low-signal" reveals dimmed low-signal rows in place.
3. "Load older" appends an older day group below.

## Explicitly NOT in this design
- Do NOT design search or actor/date filter UI (Phase 22).
- Do NOT design the superadmin app-wide/General console (Phase 22).
- Do NOT design any edit/delete affordance — the log is append-only & read-only.
- Do NOT design auth/login event rows (Phase 22).

## Design Constraints
- Desktop ≥ 1280px two-column; mobile ≤ 640px single column + bottom nav
- Rounded corners: cards rounded-2xl, chips rounded-full
- Spacing: gap-3 between rows, gap-8 between day groups
- Animations: motion-safe fade/slide on insert only; respect prefers-reduced-motion
- Both modes required; light primary
- Accessibility: WCAG AA contrast, ≥44px touch targets, time as `<time datetime>`,
  source badge has visible text (not colour-only)
