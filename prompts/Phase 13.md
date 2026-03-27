# Catalyst Glass Design System Implementation Plan

## Context

The Catalyst trip journal app currently uses a functional but basic design system (`--ha-` CSS variables, bordered cards, simple grid layouts). A new "Catalyst Glass" design has been created in Google Stitch that introduces a Material Design 3-inspired color system, glassmorphism effects, editorial typography, a "no-line" tonal layering philosophy, and a magazine-style layout for trip content.

The goal is to implement this design across all screens while keeping the app functional at every stage. The design files live in `designs/catalyst_glass/` with reference HTML, screenshots, color tokens, and a design system spec.

---

## Key Design Deltas (Current vs Target)

| Aspect | Current | Target |
|--------|---------|--------|
| **Background** | `#f1f5f9` (cool slate) | `#faf8ff` (warm purple-white) |
| **Body font** | Space Grotesk only | **Inter** for body, Space Grotesk for headlines |
| **Card borders** | `1px solid #e2e8f0` | **No borders** — tonal surface layering |
| **Card bg** | `#ffffff` on `#f1f5f9` | `surface_container_lowest` (#fff) on `surface_container_low` (#f2f3ff) |
| **Shadows** | `rgba(15,23,42,0.35)` | Ambient auras: `rgba(19,27,46,0.08)` — much softer |
| **Buttons** | Flat accent bg | **Gradient** (primary→primary_container), larger padding |
| **Inputs** | White bg + border | `surface_container_highest` bg, no border, ghost-border on focus |
| **Icons** | Custom SVG Phlex components | **Keep SVGs** (Material Symbols font too heavy to add) |
| **Sidebar** | Dark gradient, collapsible `<details>` | Dark navy with user profile header, glassmorphism optional |
| **Trip cards** | Text-only, bordered | **Large cover images** (16:10), editorial layout, state chips |
| **Journal entries** | Grid cards | **Magazine-style editorial** with full-width images |
| **Login** | Card within sidebar layout | **Centered full-page** with glass panel + decorative blobs |
| **Mobile** | Collapsed sidebar only | **Bottom tab bar** + glass top bar |
| **Headlines** | 3xl-4xl, standard tracking | **4xl-5xl, tracking-tighter** (-0.02em), editorial feel |

---

## Phased Implementation

### Phase 0: Foundation — CSS Variables & Fonts
**Files:** `app/assets/tailwind/application.css`, `app/views/layouts/application_layout.rb`

1. **Add Inter font** import alongside Space Grotesk
2. **Expand `--ha-` CSS variables** to include the full M3 surface hierarchy:
   - Map new tokens: `--ha-bg` → `#faf8ff`, add `--ha-surface-low`, `--ha-surface-container`, `--ha-surface-high`, `--ha-surface-highest`
   - Add `--ha-primary` (#00668a), `--ha-primary-container` (#38bdf8), `--ha-secondary` (#006c4b), `--ha-secondary-container` (#64f9bc), `--ha-tertiary` (#855300), `--ha-tertiary-container` (#f1a02b)
   - Add `--ha-on-surface` (#131b2e), `--ha-on-surface-variant` (#3e484f), `--ha-outline` (#6e7980), `--ha-outline-variant` (#bdc8d1)
   - Update dark mode counterparts
3. **Update `.ha-card`**: Remove border, use ambient shadow (`0 20px 40px -12px rgba(19,27,46,0.08)`), bg stays `--ha-card` (surface_container_lowest)
4. **Update `.ha-button-primary`**: Gradient bg (`linear-gradient(135deg, var(--ha-primary), var(--ha-primary-container))`), white text, larger padding
5. **Update `.ha-input`**: bg → `--ha-surface-highest`, remove border, ghost-border on focus
6. **Add `.ha-glass`** utility: `rgba(255,255,255,0.7)` + `backdrop-filter: blur(20px) saturate(180%)`
7. **Add `.ha-gradient-aura`** utility for primary gradient CTAs
8. **Update body font-family**: Set body to Inter, keep Space Grotesk for headings via utility classes
9. **Docker rebuild** to compile new Tailwind classes

**Verification:** App still loads, all pages render, dark mode works, no visual regressions in basic structure.

### Phase 1: Layout & Navigation
**Files:** `app/views/layouts/application_layout.rb`, `app/components/sidebar.rb`, `app/components/nav_item.rb`, `app/components/page_header.rb`

**New components:** `app/components/mobile_bottom_nav.rb`, `app/components/mobile_top_bar.rb`

1. **Update `application_layout.rb`**:
   - Background decorations: larger blurred blobs with primary/secondary tints
   - Add Inter font link in `<head>`
   - Render mobile top bar (md:hidden)
   - Render mobile bottom nav (md:hidden)
   - Update main content area background to `--ha-bg` (#faf8ff)
2. **Update `sidebar.rb`**:
   - Add user profile section at top (avatar + name + role) — read from `current_account`
   - Simplify nav items to match design (Journal/Map/Memories/Discover → map to existing routes: Overview/Trips/Users/Requests)
   - Add rounded-r-[2rem] to sidebar container
   - Status counter at bottom ("X Entries")
   - Hide on mobile (`hidden md:flex`)
3. **Create `mobile_bottom_nav.rb`**:
   - Fixed bottom, glass effect bg, rounded-t-[2.5rem]
   - 4 tabs: Home, Trips, Users, Profile (map to existing routes)
   - Active state detection via controller_name
4. **Create `mobile_top_bar.rb`**:
   - Fixed top, glass bg, hamburger + title + avatar
   - md:hidden
5. **Update `page_header.rb`**:
   - Larger headlines (text-4xl md:text-5xl), font-headline class, tracking-tighter
   - Remove overline, use lighter subtitle styling

**Verification:** Navigate all pages on desktop and mobile viewports, sidebar renders correctly, mobile nav appears below md breakpoint.

### Phase 2: Dashboard (Welcome/Home)
**Files:** `app/views/welcome/home.rb`

1. **Redesign home page** to match dashboard design:
   - Hero welcome: "Welcome back, {name}" (4xl-5xl headline)
   - Quick-action pill cluster: "New Trip", "New Entry" buttons (gradient primary + ghost secondary)
   - Active trip card: If user has a started trip, show bento card with cover image, stats (entries count, pending items), member avatars
   - Recent memories: Image grid (2x2 on mobile, 4-col on desktop) from latest journal entry images
   - Fallback: Keep current cards for logged-out state (request access / sign in)
2. **Keep conditional logic**: Different view for logged-in vs logged-out users

**Verification:** Home page renders for logged-in user with trip data, logged-out user sees access/signin cards.

### Phase 3: Trips Index & Trip Cards
**Files:** `app/views/trips/index.rb`, `app/components/trip_card.rb`

1. **Redesign `trip_card.rb`**:
   - Large cover image area (aspect-[16/10]) — use first journal entry image or placeholder gradient
   - Remove borders, use tonal layering
   - State badge as chip (rounded-full, colored bg)
   - Date in monospace font (font-mono)
   - "View details →" link with arrow animation on hover
   - Cancelled trips: grayscale image, opacity-80, hover removes effect
2. **Redesign `trips/index.rb`**:
   - Editorial header: "My Trips" (5xl), subtitle, search input + "New Trip" gradient button
   - 2-column grid (md:grid-cols-2) with 2rem gap
   - Decorative footer: "EXPLORE" watermark text (8xl, 30% opacity)

**Verification:** Trips index shows cards with images, state badges, all CRUD still works.

### Phase 4: Trip Detail (Show)
**Files:** `app/views/trips/show.rb`

1. **Full-screen hero cover**: If trip has journal entries with images, use first image as full-bleed hero
   - Gradient overlay (dark bottom)
   - Trip name as editorial headline overlay (5xl-7xl white text)
   - Location + date chips with glass bg
   - "Open Journal" gradient CTA button
   - Member avatar cluster
2. **Below-fold content**: Journal entries list, state transitions, checklists — use existing components with updated styling
3. **Fallback**: If no images, use a gradient background with the trip name

**Verification:** Trip show page renders with hero for trips with images, standard layout for trips without.

### Phase 5: Journal Feed & Entry Detail
**Files:** `app/views/journal_entries/show.rb`, `app/components/journal_entry_card.rb`

1. **Redesign journal entry cards** (shown within trip show):
   - Magazine-style: Large image + editorial text
   - Entry date as overline
   - Title in headline font, tight tracking
   - Description as body text (Inter font)
   - Alternating image/text layout for visual variety
2. **Redesign journal entry detail**:
   - Full-width hero image at top
   - Editorial headline (tight tracking, large)
   - Body text in Inter with good line-height
   - Pull-quote styling for blockquotes (left border, italic)
   - Comments as conversation thread with avatar circles
   - Floating "New Comment" button

**Verification:** Journal entries render with images, comments work, reactions work.

### Phase 6: Forms (Create/Edit Entry, Trip Form)
**Files:** `app/components/trip_form.rb`, `app/components/journal_entry_form.rb`, `app/components/comment_form.rb`

1. **Update input styling**: Use `.ha-input` updated styles (no border, surface_highest bg)
2. **Journal entry form**: Add cover photo upload prominence, metadata chips area (location, mood, tags)
3. **Trip form**: Clean form with date inputs, description
4. **Comment form**: Inline input with send button

**Verification:** All forms submit correctly, validation errors display.

### Phase 7: Authentication Pages
**Files:** `app/views/rodauth/login.rb`, `app/components/rodauth_login_form.rb`, related Rodauth views

1. **Login page**: Full-page centered layout (break out of sidebar layout)
   - Brand identity: Icon + "Catalyst" headline + tagline
   - Glass-panel form card with icon-prefixed inputs
   - Gradient "Login" button
   - "OR CONTINUE WITH" divider
   - Passkey button
   - "Create Account" link
   - Decorative background aura blobs
2. **Create account, verify, email auth**: Similar glass-panel treatment
3. **Layout consideration**: Auth pages may need a separate layout without sidebar, or hide sidebar conditionally

**Verification:** Login flow works end-to-end, create account + verify email works, passkey flow works.

### Phase 8: Account Settings & Collaboration
**Files:** `app/views/accounts/show.rb`, `app/components/account_details.rb`, `app/views/users/index.rb`, `app/components/user_card.rb`

1. **Account page**: Circular avatar with edit overlay, role chips, settings sections as icon cards
2. **Users/Collaboration Hub**: Team member cards with avatars, pending invitations, access requests with approve/reject

**Verification:** Account CRUD works, user management works.

### Phase 9: Checklists
**Files:** `app/components/checklist_card.rb`, related checklist views

1. **Categorized sections** with progress indicators
2. **Checklist items** with toggle checkboxes
3. **Progress bar** per section
4. **"Almost Ready" banner** when near completion

**Verification:** Checklist CRUD and toggle work.

### Phase 10: Dark Mode & Polish
**Files:** `app/assets/tailwind/application.css`, all components

1. **Dark mode variables**: Flip surface hierarchy luminosity
2. **Increase backdrop-blur** to 30px in dark mode
3. **Test all screens** in dark mode
4. **Animation polish**: Ensure ha-fade, ha-rise, cubic-bezier transitions work
5. **Accessibility audit**: Ghost borders at 15% opacity where needed, focus states

**Verification:** Toggle dark mode on every page, no contrast issues.

---

## Critical Files Reference

### Must Modify
| File | Purpose |
|------|---------|
| `app/assets/tailwind/application.css` | Design tokens, component classes |
| `app/views/layouts/application_layout.rb` | Layout, fonts, mobile nav |
| `app/components/sidebar.rb` | Navigation redesign |
| `app/components/nav_item.rb` | Nav item styling |
| `app/components/page_header.rb` | Editorial headlines |
| `app/components/trip_card.rb` | Image-first trip cards |
| `app/components/journal_entry_card.rb` | Magazine-style entries |
| `app/components/user_card.rb` | Avatar-centric cards |
| `app/components/trip_state_badge.rb` | Material chip badges |
| `app/components/rodauth_login_form.rb` | Glass-panel auth |
| `app/views/welcome/home.rb` | Dashboard redesign |
| `app/views/trips/index.rb` | Editorial trip grid |
| `app/views/trips/show.rb` | Hero cover layout |
| `app/views/journal_entries/show.rb` | Editorial detail |
| `app/views/rodauth/login.rb` | Full-page auth layout |
| `app/views/accounts/show.rb` | Avatar settings |
| `app/views/users/index.rb` | Collaboration hub |

### Must Create
| File | Purpose |
|------|---------|
| `app/components/mobile_bottom_nav.rb` | Bottom tab bar |
| `app/components/mobile_top_bar.rb` | Glass header bar |

### Design Reference
| File | Purpose |
|------|---------|
| `designs/catalyst_glass/design_system.md` | Design philosophy & rules |
| `designs/catalyst_glass/design_system.json` | Tokens & font config |
| `designs/catalyst_glass/colors.json` | Full M3 color palette |
| `designs/catalyst_glass/screens/html/*.html` | Reference HTML for each screen |
| `designs/catalyst_glass/screens/images/*.png` | Visual reference screenshots |

---

## UI Designer Skill Protocol

Every component change **must** follow the UI Designer skill workflow:

### 1. Reference Library Lookup (Before Building)
Search `~/Workspace/WebUIComponents/TailwindCSS/application_ui/` for matching patterns:
- **Navigation**: `application_ui/navigation/sidebar_navigation/`, `application_ui/navigation/navbars/`
- **Cards**: `application_ui/layout/cards/`
- **Badges**: `application_ui/elements/badges/`
- **Buttons**: `application_ui/elements/buttons/`
- **Forms**: `application_ui/forms/`
- **Lists/Feeds**: `application_ui/lists/`
- **Headings**: `application_ui/headings/page_headings/`
- **Overlays**: `application_ui/overlays/`
- **Containers**: `application_ui/layout/containers/`

Read matching HTML templates and translate to Phlex syntax, then apply project `--ha-*` design tokens.

### 2. Component Conventions
- Inherit from `Components::Base`
- Use `view_template` method
- Keep under 100 lines; split larger ones into sub-components
- Include necessary Rails helpers (`Phlex::Rails::Helpers::LinkTo`, etc.)
- Card ID: `id: dom_id(@record)` for Turbo targeting
- Use design tokens (`--ha-*` variables) not hardcoded colors
- Follow existing patterns for overlines, card actions, rise animations

### 3. UI Library YAML Sync (After Every Component Change)
**Every new or modified component must have a matching `ui_library/<name>.yml` file.**

```yaml
component: Components::ClassName
file: app/components/class_name.rb
library_source: application_ui/category/subcategory  # or null if custom
library_variant: variant_name.html                    # or null
description: What this component renders.
design_tokens:
  - ha-card
  - ha-overline
tailwind_classes:
  - p-6, text-lg, font-semibold
```

### 4. Regenerate Index
After YAML updates: `ruby ui_library/generate_index.rb`

### UI Library Files to Create/Update per Phase

| Phase | YAML Files to Update | YAML Files to Create |
|-------|---------------------|---------------------|
| **0** | — (CSS only) | — |
| **1** | `sidebar.yml`, `page_header.yml` | `mobile_bottom_nav.yml`, `mobile_top_bar.yml` |
| **2** | — | `dashboard_hero.yml` (if extracted) |
| **3** | `trip_card.yml` | — |
| **4** | — | — (trip show is a view, not a component) |
| **5** | — | `journal_entry_card.yml` (create if missing) |
| **6** | — | `trip_form.yml`, `journal_entry_form.yml`, `comment_form.yml` (create if missing) |
| **7** | — | `rodauth_login_form.yml` (create if missing) |
| **8** | — | `user_card.yml`, `account_details.yml` (create if missing) |
| **9** | — | `checklist_card.yml` (create if missing) |
| **10** | All files — audit `design_tokens` and `tailwind_classes` accuracy | — |

**Existing YAML files** that must be updated when their component changes:
- `ui_library/sidebar.yml` — Phase 1
- `ui_library/trip_card.yml` — Phase 3
- `ui_library/trip_state_badge.yml` — Phase 3
- `ui_library/page_header.yml` — Phase 1
- `ui_library/comment_card.yml` — Phase 5
- `ui_library/export_card.yml` — Phase 3 (if redesigned)
- `ui_library/pwa_install_banner.yml` — Phase 10 (polish)

---

## Icon Strategy

**Decision: Keep existing SVG icon components.** The design uses Material Symbols but adding the font (~300kb) is heavy. The existing SVG icons cover all needed glyphs. Where the design shows new icons (edit_note, photo_library, explore), create new SVG icon components following the existing pattern in `app/components/icons/`.

---

## Constraints & Risks

1. **Tailwind JIT**: New utility classes need Docker rebuild (`bin/cli app rebuild`). Do this once in Phase 0, then sparingly.
2. **No-Line Rule**: Removing all borders at once may cause visual regression. Phase 0 updates `.ha-card` globally — test carefully.
3. **Auth layout**: Login/create-account pages currently render inside the sidebar layout. Phase 7 needs a conditional layout or separate layout class.
4. **Cover images**: Trip cards need images. Trips without journal entry images need a gradient placeholder. The current TripCard has no image support.
5. **Inter font**: Adding a new font increases page weight. Use `display=swap` to avoid FOIT.
6. **Mobile bottom nav**: New component, needs to not conflict with existing sidebar on desktop.
7. **UI Library sync**: Every component modification must update the corresponding `.yml` file and regenerate the index.

---

## Verification Strategy

After each phase:
1. `bin/cli app rebuild` (if new Tailwind classes were introduced)
2. `bin/cli app restart`
3. Run `bundle exec rake project:lint` (RuboCop)
4. Run `bundle exec rake project:tests`
5. Visual check via `agent-browser` at `https://catalyst.workeverywhere.docker/`
6. Check both desktop and mobile viewports
7. Toggle dark mode
8. **Verify `ui_library/*.yml` files are in sync** — run `ruby ui_library/generate_index.rb` and confirm no errors
9. **Trigger `ui-designer` skill** for each component to search reference library before building
10. **Trigger `ui-polish` skill** at end of each phase for visual quality review
