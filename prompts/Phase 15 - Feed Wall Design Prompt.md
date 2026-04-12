# Google Stitch Prompt — Journal Entries Feed Wall

## App Context

Trip Journal is a collaborative travel journaling PWA. The design language is
**modern glassmorphic Material 3** with generous rounded corners (2rem),
subtle backdrop blur, and a muted ocean-inspired colour palette. The app uses
a persistent sidebar on desktop and a bottom tab bar on mobile.

This screen set rethinks the Journal Entries section of a trip. Today, entries
are rendered as short cards that link out to a dedicated detail page. That
pattern makes a trip feel like a blog — disconnected posts instead of a
continuous story. The redesign turns the entries section into a **feed wall**:
every entry is rendered directly under the trip description, newest first,
and each card can expand in-place to show body, photos, reactions, and
comments. There is no separate entry page.

## Colour System

### Light Mode
- **Background:** `#faf8ff` (cool off-white)
- **Card:** `#ffffff` with `box-shadow: 0 20px 40px -12px rgba(19,27,46,0.08)`
- **Primary:** `#00668a` (deep teal)
- **Primary container:** `#38bdf8` (sky blue)
- **Text:** `#131b2e` (near-black)
- **Muted text:** `#3e484f` (slate grey)
- **Surface variant:** `#dae2fd` (pale lavender)
- **Danger/badge:** `#ef4444` (red-500)
- **Success/reactions active:** `#00668a` (primary)

### Dark Mode
- **Background:** `#0b1120` (deep navy)
- **Card:** `#111c2e` (dark slate)
- **Primary:** `#7bd0ff` (light sky)
- **Text:** `#e2e8f0` (cool white)
- **Muted text:** `#94a3b8` (blue-grey)
- **Divider:** `#1e293b`

### Sidebar (Both Modes)
- **Panel background:** `#0b1220` with 80% opacity + backdrop blur 30px
- **Panel text:** `#e2e8f0`
- **Nav items:** rounded-2xl, 4px padding, 3-gap icon+label, hover lift with primary highlight
- **Active nav:** `bg-[primary-container]/10` with primary text colour

## Typography
- **Headline font:** Inter (font-headline), tracking -0.02em
- **Page titles:** 2.25rem/3rem (text-4xl md:text-5xl), bold
- **Section labels:** uppercase, letter-spacing 0.1em, 10px, muted (ha-overline class)
- **Entry title:** 1.25rem (text-xl), bold, tracking-tight
- **Body:** 14px, medium weight
- **Prose (expanded entry body):** 16px line-height 1.75, max-w-none
- **Timestamps & metadata:** 12px, muted colour

## Component Patterns
- **Cards:** rounded-2xl, white bg (dark: #111c2e), subtle shadow, hover lift -translate-y-1
- **Buttons — primary:** rounded-xl, bg-primary, white text, px-5 py-2.5
- **Buttons — secondary:** rounded-xl, border, transparent bg, text-primary
- **Icon buttons:** 40×40px, rounded-full, subtle hover background, stroke icons inside
- **Icons:** 16×16 (or 20×20 for headers) stroke icons, `currentColor`, stroke-width 1.5
- **Chips (reaction pills):** rounded-full, 28px tall, 10px horizontal padding, subtle bg, 1px border, 6px gap between emoji and count

---

## Design Request: Journal Entries Feed Wall (5 Screens)

### Screen 1 — Trip Show Page with Collapsed Feed (Desktop, Light Mode)

**Layout:** Full desktop view (1280px), sidebar on the left (240px), content
area (~1000px) on the right. Trip hero at the top, then the feed wall below.

**Trip hero (top of content area):**
- Section label: "TRIP" (ha-overline)
- Title: "Iceland — Ring Road, April 2026" (text-4xl, bold, tight tracking)
- Date range line: "Apr 4 — Apr 15, 2026" (font-mono, text-sm, muted)
- Status chip: "In progress" (rounded-full, sky-blue background, primary text, 10px padding)
- Short description paragraph (3–4 lines of lorem-ish travel blurb)
- Action row: "Edit trip", "Members (4)", "Checklists", "Export" — secondary buttons in a flex row

**Feed header:**
- Section label: "JOURNAL FEED" (ha-overline), muted
- Title: "The story so far" (text-2xl, bold)
- Right side: "New entry" primary button with plus icon

**Feed list (vertical stack, space-y-6):** Four journal entry cards, **newest at
the top**.

**Each card (collapsed state):**
- `ha-card`, rounded-2xl, padding 24px, subtle shadow
- **Top row (flex, items-start, gap-4):**
  - **Left (flex-1):**
    - Overline date: "APRIL 9, 2026" (ha-overline, muted)
    - Title: "Hiking Svartifoss at golden hour" (text-xl, bold, tight)
    - Location line with pin icon: "📍 Skaftafell, Vatnajökull National Park" (text-xs, muted)
    - Author line: small 28px avatar + "Alice Martin" (text-xs, muted)
  - **Right (flex shrink-0, items-center, gap-2):**
    - **Mute toggle (bell icon)** — icon button, 40×40, rounded-full, subtle hover bg. When subscribed (default) the bell icon is **filled primary colour**. Tooltip "Mute notifications". (See Screen 4 for the mute state.)
    - **Edit icon button** (pencil) — only shown if user can edit; 40×40 rounded-full
- **Middle (cover image, optional):**
  - 16:9 rounded-2xl image, overflow hidden, subtle hover zoom
  - If no image, skip this block
- **Description preview:** 2 lines of entry description, `line-clamp-2`, text-sm, muted
- **Footer row (flex, items-center, justify-between, mt-4, pt-4 border-top-1 surface-variant):**
  - **Left:** reaction summary pills (up to 3 most-used emoji + total count, e.g., "👍 ❤️ 🔥  12") and comment count ("💬 4 comments"), both muted text-xs
  - **Right:** "Read more ▾" text link in primary colour, semibold, text-sm

**Sample data for the four cards (top to bottom, newest first):**

1. **Apr 9** — "Hiking Svartifoss at golden hour" — Skaftafell — Alice Martin
   — preview: "The basalt columns looked unreal under the warm light — we
   stayed until the last hikers left and had the waterfall to ourselves..."
   — 12 reactions, 4 comments
2. **Apr 8** — "Black sand beach and an unexpected storm" — Reynisfjara —
   Bob Chen — preview: "The weather turned fast. We got our raincoats on
   just as the wind picked up and the puffins disappeared..."
   — 7 reactions, 2 comments
3. **Apr 6** — "First night in Vik í Mýrdal" — Vik — Joel Azemar
   — preview: "Arrived late, the guesthouse host left the keys under a stone.
   The northern lights were faint but visible..."
   — 18 reactions, 9 comments
4. **Apr 4** — "Landed in Reykjavik, picked up the van" — Keflavík Airport —
   Alice Martin — preview: "Flight was on time, rental van is a 2022
   Transporter with a pop-top..."
   — 3 reactions, 1 comment

**Spacing:** `space-y-6` between cards. Hover lift on each card
(`-translate-y-1`, shadow deepens slightly).

### Screen 2 — Same Trip Show with Second Card Expanded

Identical layout to Screen 1, but the **second card** ("Black sand beach and
an unexpected storm") is **expanded in place**. All other cards stay
collapsed. **No route change** — still on `/trips/:id`.

**Expanded card contains, top to bottom:**

1. **Header** (same as collapsed: date, title, location, author, mute toggle,
   edit button — unchanged)
2. **Hero image** — full width, 16:9, rounded-2xl (same as collapsed preview
   but no hover zoom state)
3. **Full description block** — no line clamp, text-base, muted text
4. **Rich body prose** — 3–4 paragraphs of travel prose, prose-lg styling,
   ~500 words of lorem-ish content. This is the part that was previously
   on the dedicated show page.
5. **Photo grid** — 3-column grid of thumbnails (aspect-ratio 4/3, rounded-xl,
   hover zoom). Show 6 photos total.
6. **Reaction bar** — full-width row:
   - Left: the 6 reaction emoji buttons in a row (👍 ❤️ 🎉 👀 🔥 🚀) — each a
     rounded-full chip, 36px tall, hoverable. The ones the current user has
     clicked are in primary-container background with primary text; unused
     ones have a transparent background with a muted border.
   - Right: total reaction count "12 reactions"
7. **Comments header** — "Comments (2)" (text-lg, semibold) + small horizontal
   divider line
8. **Comment list** — two comments stacked, `space-y-4`. Each comment:
   - 32px avatar circle on the left
   - Bubble on the right: author name (semibold, text-sm), timestamp
     ("2 hours ago", text-xs, muted), comment body (text-sm)
   - If the user owns the comment, small edit / delete icon buttons on the right edge
9. **New comment form** — full-width textarea placeholder "Write a comment…",
   rounded-xl, surface-variant background, with a "Post" primary button
   aligned right below it
10. **Collapse link** — bottom of the expanded body, centred: "Collapse ▴"
    text link in primary colour

**Transition hint:** An arrow/chevron on the "Read more" link rotates 180°
when the card is expanded, signalling state. Include a subtle divider line
between the description block and the body prose.

### Screen 3 — Feed Wall Mobile (393px, iPhone 14 Pro)

Same content as Screen 1 but in the mobile frame. Sidebar is hidden; bottom
tab bar is present with icons: Overview, Trips (active), Feed/Notifications,
Account.

**Differences from desktop:**
- Content area is full width, 20px horizontal padding.
- Cards are slightly smaller (padding 20px, title text-lg instead of text-xl).
- Cover image is 4:3 instead of 16:9.
- Mute toggle and edit button stay in the top-right corner of each card,
  still 40×40 tap targets.
- "Read more" link is full-width at the bottom of the card (not right-aligned)
  so it's a bigger tap target.
- Reaction summary and comment count stack below the description instead of
  sharing a footer row.
- Show the same four entries, top card ("Hiking Svartifoss at golden hour")
  has its cover image visible.

### Screen 4 — Mute State Comparison (Zoom-in on One Card)

Two side-by-side mini-frames showing only the **top-right area of a single
card header** — the mute toggle in two states.

**Frame A — "Subscribed (default)":**
- 40×40 rounded-full icon button, subtle primary-container/10 background
- **Filled bell icon** in primary colour (#00668a)
- Tooltip (visible in the mockup): "Notifications on — click to mute"

**Frame B — "Muted":**
- 40×40 rounded-full icon button, transparent background
- **Bell-off icon** (stroke with diagonal slash) in muted text colour (#3e484f)
- Tooltip (visible in the mockup): "Notifications off — click to resume"

Above each frame, a small caption label: "Subscribed" / "Muted". Include a
1-line explanatory text below both frames:
"Every trip member is subscribed by default when a new entry is posted.
Mute any entry directly from the feed with one click."

### Screen 5 — Empty Feed State

Trip show page with the **feed section empty** — no entries have been created
yet.

**Content area:**
- Trip hero is unchanged (same title, date, description)
- Feed header: "JOURNAL FEED" overline + "The story so far" title, no "New
  entry" button visible in the header (it's moved to the empty state CTA)
- Inside the feed area, one large placeholder card:
  - Centred feather/pen icon (48×48, stroke, muted colour)
  - Below: "No entries yet" (text-lg, font-medium, muted)
  - Below that: "Capture a moment, a photo, or a thought from the road.
    Every entry becomes part of the trip's timeline." (text-sm, lighter muted,
    max-width 440px, centred)
  - Below that: "Write the first entry" primary button with plus icon

---

## Interaction Patterns to Visualise

1. **Expansion is in-place.** The URL does **not** change when a card
   expands. Users stay on `/trips/:id` and only one page is ever loaded for
   an entire trip's feed.
2. **Newest at the top.** Cards are sorted by `entry_date` descending. The
   most recent trip moment is always the first thing the user sees.
3. **Mute is one click.** The bell icon on every card swaps state without
   any navigation, confirmation dialog, or page reload.
4. **Comments and reactions live inside the expanded card.** When a user
   writes a comment or clicks an emoji, the change is streamed into that
   card only — the rest of the feed doesn't re-render.

## Explicitly **not** in this design

- Do NOT design a separate "journal entry detail page" — it is being deleted.
- Do NOT design a dropdown/popover for notification settings — the bell
  icon directly toggles the subscription.
- Do NOT design a "follow this entry" call-to-action — users are already
  following by default.
- Do NOT add pagination or "load more" — entries are listed in full for now.
- Do NOT design a sticky sub-header — keep the trip hero and feed as a
  normal vertical scroll surface.

---

## Design Constraints

- **Desktop width:** 1280px with 240px sidebar, content area ~1000px
- **Mobile width:** 393px (iPhone 14 Pro) — sidebar hidden, bottom tab bar
- **Rounded corners:** 2rem (rounded-2xl) for cards, 1rem (rounded-xl) for buttons and image frames, rounded-full for icon buttons and reaction chips
- **Spacing:** 8px grid, generous whitespace, `space-y-6` between feed cards
- **Animations:** subtle fade-in on card entrance (ha-fade-in), hover lift
  on cards, 180° chevron rotation when expanding
- **Both modes:** Light mode is primary. Please also generate a dark mode
  variant of Screen 2 (expanded card) so we can see prose, photo grid, and
  reaction bar contrast on the dark background.
- **Accessibility:**
  - Mute toggle must have a visible label or tooltip — icon alone is not
    sufficient.
  - Reaction emoji buttons must have a text label beneath or in an aria-label.
  - Expand/collapse state must be signalled by both the chevron rotation AND
    a text label change ("Read more" ↔ "Collapse") so it doesn't rely on
    colour or animation alone.
  - Hit targets for mobile are minimum 40×40px.
