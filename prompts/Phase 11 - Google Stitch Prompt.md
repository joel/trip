# Google Stitch Prompt — Notification Centre

## App Context

Trip Journal is a collaborative travel journaling PWA. The design language is **modern glassmorphic Material 3** with generous rounded corners (2rem), subtle backdrop blur, and a muted ocean-inspired colour palette. The app uses a persistent sidebar on desktop and a bottom tab bar on mobile.

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

### Dark Mode
- **Background:** `#0b1120` (deep navy)
- **Card:** `#111c2e` (dark slate)
- **Primary:** `#7bd0ff` (light sky)
- **Text:** `#e2e8f0` (cool white)
- **Muted text:** `#94a3b8` (blue-grey)

### Sidebar (Both Modes)
- **Panel background:** `#0b1220` with 80% opacity + backdrop blur 30px
- **Panel text:** `#e2e8f0`
- **Nav items:** rounded-2xl, 4px padding, 3-gap icon+label, hover lift with primary highlight
- **Active nav:** `bg-[primary-container]/10` with primary text colour

## Typography
- **Headline font:** Inter (font-headline), tracking -0.02em
- **Page titles:** 2.25rem/3rem (text-4xl md:text-5xl), bold
- **Section labels:** uppercase, letter-spacing 0.1em, 10px, muted (ha-overline class)
- **Body:** 14px, medium weight
- **Timestamps:** 12px, muted colour

## Component Patterns
- **Cards:** rounded-2xl, white bg (dark: #111c2e), subtle shadow, hover lift -translate-y-1
- **Buttons — primary:** rounded-xl, bg-primary, white text, px-5 py-2.5
- **Buttons — secondary:** rounded-xl, border, transparent bg, text-primary
- **Icons:** 16×16 stroke icons, `currentColor`, stroke-width 1.5

---

## Design Request: Notification Centre (3 Screens)

### Screen 1: Notifications Index Page (With Notifications)

**Layout:** Full page, same structure as Users or Trips index. Page header top-left, content below.

**Header area:**
- Section label: "ACTIVITY" (ha-overline style, uppercase, small, muted)
- Title: "Notifications" (text-4xl, bold, tight tracking)
- Right side: "Mark all as read" secondary button (only visible when unread notifications exist)

**Notification list:** Vertical stack with `space-y-8` between date groups

**Date group:**
- Date heading: "Today" / "Yesterday" / "March 25, 2026" — small (text-sm), semibold, muted colour
- Cards below with `space-y-2` gap

**Notification card:**
- White card (ha-card), padding 16px, rounded-2xl
- Layout: horizontal flex, `items-start`, `gap-4`
- **Left:** Unread indicator dot — 10px circle, primary colour (`#00668a`) when unread, transparent when read
- **Middle (flex-1):**
  - Line 1: **"Alice Martin"** (semibold) + "created a new journal entry" (normal weight), text-sm
  - Line 2: "3 hours ago" — text-xs, muted colour
- **Right:** "Mark read" text link — text-xs, primary colour, hover underline. Hidden when already read.
- **Read state:** Entire card at 60% opacity when read

**Notification types (example content):**
- "**Alice Martin** created a new journal entry" (entry_created)
- "**Bob Chen** commented on a journal entry" (comment_added)
- "**Joel Azemar** added you to a trip" (member_added)

**Sample data for the mockup:**

Today:
- Alice Martin created a new journal entry — 2 hours ago (unread)
- Bob Chen commented on a journal entry — 4 hours ago (unread)

Yesterday:
- Joel Azemar added you to a trip — 1 day ago (read, 60% opacity)
- Carol Nguyen created a new journal entry — 1 day ago (read)

### Screen 2: Notifications Empty State

**Same page layout** (header with "ACTIVITY" / "Notifications"), but no "Mark all as read" button.

**Centre of content area:**
- Bell icon — 48×48px, stroke style, muted colour (`#3e484f`), centred horizontally
- Below icon: "No notifications yet" — text-lg, font-medium, muted
- Below that: "You'll see activity from your trips here." — text-sm, lighter muted

### Screen 3: Sidebar with Notification Bell + Badge

**Show the sidebar navigation** with these items in order:
1. **User profile** area at top — avatar circle (gradient blue-to-teal, initials "JA"), name "Joel Azemar", role "Super Admin"
2. Overview (home icon)
3. Trips (map icon)
4. **Notifications** (bell icon) — **with red badge showing "3"**
5. Users (people icon)
6. Requests (plus icon)
7. Invitations (create-account icon)
8. [gap / spacer]
9. New user (plus icon)
10. Dark mode toggle
11. My account
12. Add passkey
13. Sign out

**Bell badge specification:**
- Position: absolute, -top-1 -right-1 relative to the bell icon
- Size: 20px height, min-width 20px, pill shape (rounded-full)
- Background: `#ef4444` (red-500)
- Text: white, 10px, bold
- Content: "3" (or "99+" if over 99)
- Hidden when count is 0

**Active state:** When on the Notifications page, the "Notifications" nav item should have the active style (primary colour text, subtle primary-container background at 10% opacity)

---

## Bonus Screen (Optional): Journal Entry with Follow Button

Show a journal entry page action bar with these buttons in a horizontal row:
- "Edit" — secondary button
- "Delete" — danger button (red text/border)
- "Back to trip" — secondary button
- **"Follow"** — secondary button (when not subscribed)
- OR **"Following"** — secondary button (when subscribed, visually identical but different label)

---

## Design Constraints

- **Desktop width:** 1280px with 240px sidebar, content area ~1000px
- **Mobile width:** 393px (iPhone 14 Pro) — sidebar hidden, bottom tab bar with bell icon tab
- **Rounded corners:** 2rem (rounded-2xl) for cards and nav items, 1rem (rounded-xl) for buttons
- **Spacing:** 8px grid, generous whitespace
- **Animations:** Subtle fade-in entrance (ha-fade-in), hover lift on cards
- **Both modes:** Please generate light mode as the primary design, with a dark mode variant if possible
- **No dropdown menus:** Notifications are a full page, not a popover/dropdown
- **Accessibility:** Unread indicator must not rely on colour alone — the opacity difference (100% vs 60%) and the "Mark read" button presence provide secondary signals
