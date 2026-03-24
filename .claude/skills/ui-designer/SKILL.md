---
name: ui-designer
description: Build production-grade frontend interfaces using Tailwind CSS, Phlex components, and Hotwire (Turbo + Stimulus). Use this skill whenever the user asks to build, style, or improve web pages, UI components, layouts, forms, navigation, dashboards, or any visual frontend element. Also use when the user mentions designing a view, creating a Phlex component, styling with Tailwind, adding a sidebar, building a table, creating a card, or beautifying any web UI. This skill has access to a 657-component reference library to produce polished, consistent results. Always trigger this skill for ANY UI-related work -- even small styling tweaks, layout adjustments, or "make this look better" requests.
---

# UI Designer

Build and modify frontend interfaces for this Rails + Phlex + Tailwind project. Every UI change must go through this skill to ensure consistency with the design system and reuse of existing library components.

## UI Components Library

The project has access to a **657-component Tailwind CSS reference library** at:

```
~/Workspace/WebUIComponents/TailwindCSS/
```

### Library Structure

| Category | Count | Path |
|----------|-------|------|
| **Application UI** | 364 | `application_ui/` |
| -- Application Shells | 23 | `application_shells/` (sidebar, stacked, multi-column) |
| -- Data Display | 19 | `data_display/` (calendars, description lists, stats) |
| -- Elements | 45 | `elements/` (avatars, badges, buttons, button groups, dropdowns) |
| -- Feedback | 12 | `feedback/` (alerts, empty states) |
| -- Forms | 74 | `forms/` (action panels, checkboxes, comboboxes, form layouts, input groups, radio groups, select menus, sign-in forms, textareas, toggles) |
| -- Headings | 25 | `headings/` (card headings, page headings, section headings) |
| -- Layout | 38 | `layout/` (cards, containers, dividers, list containers, media objects) |
| -- Lists | 44 | `lists/` (feeds, grid lists, stacked lists, tables) |
| -- Navigation | 54 | `navigation/` (breadcrumbs, command palettes, navbars, pagination, progress bars, sidebar navigation, tabs, vertical navigation) |
| -- Overlays | 24 | `overlays/` (drawers, modal dialogs, notifications) |
| -- Page Examples | 6 | `page_examples/` (detail, home, settings screens) |
| **Ecommerce** | 114 | `ecommerce/` |
| **Marketing** | 179 | `marketing/` |

### How to Use the Library

**Before creating any new UI component, search the library first:**

```bash
# Search by component type
ls ~/Workspace/WebUIComponents/TailwindCSS/application_ui/elements/badges/
ls ~/Workspace/WebUIComponents/TailwindCSS/application_ui/layout/cards/
ls ~/Workspace/WebUIComponents/TailwindCSS/application_ui/lists/stacked_lists/

# Read a component to see the HTML/Tailwind pattern
cat ~/Workspace/WebUIComponents/TailwindCSS/application_ui/elements/badges/flat.html
```

**Decision flow:**

1. **Search the library** for the component type you need (card, badge, form, list, etc.)
2. **Found a match?** Read the HTML, adapt it to Phlex syntax, apply project design tokens (`--ha-*` CSS variables). Document the mapping in `ui_library/` (see below).
3. **No match?** Build from scratch using the project design system. Still create an entry in `ui_library/` for future reference.

### Adapting Library Components to Phlex

Library components are raw HTML + Tailwind. To use them in this project:

1. Read the HTML from the library file
2. Convert to Phlex Ruby syntax (HTML tags become method calls)
3. Replace hardcoded Tailwind colors with project CSS variables (`--ha-text`, `--ha-muted`, `--ha-accent`, etc.)
4. Apply project conventions (see Design System section below)
5. Document the adaptation in `ui_library/`

**Example: Library badge -> Project badge**

Library HTML (`application_ui/elements/badges/flat.html`):
```html
<span class="inline-flex items-center rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-700">Badge</span>
```

Phlex adaptation:
```ruby
span(class: "rounded-full px-3 py-1 text-xs font-medium " \
            "bg-emerald-100 text-emerald-800 " \
            "dark:bg-emerald-500/10 dark:text-emerald-300") do
  plain "Badge"
end
```

Changes: added dark mode variants, used project-consistent spacing (`px-3 py-1`), matched the border-radius language.

### Browsing the Libraries

Both libraries have browsable `index.html` files:

- **Reference library**: `open ~/Workspace/WebUIComponents/TailwindCSS/index.html` (657 components)
- **Project library**: `open ui_library/index.html` (current project components)

### Regenerating the Project Index

After adding or modifying `ui_library/*.yml` entries, regenerate the browsable index:

```bash
mise x -- ruby ui_library/generate_index.rb
```

## Project UI Library (`ui_library/`)

The directory `ui_library/` at the project root tracks which library components are in use and how they map to project Phlex components. This keeps the project in sync with the reference library.

**Each entry is a YAML file** named after the project component:

```yaml
# ui_library/trip_card.yml
component: Components::TripCard
file: app/components/trip_card.rb
library_source: application_ui/layout/cards
library_variant: null  # custom, not a direct adaptation
description: Trip card with overline, title, dates, description, state badge, and action buttons.
design_tokens:
  - ha-card (border-radius, border, background, shadow)
  - ha-card-actions (margin-top, border-top, padding-top)
  - ha-overline (font-size, weight, uppercase, tracking, color)
tailwind_classes:
  - p-6, mt-2, text-lg, text-xs, text-sm
  - font-semibold, line-clamp-2
  - flex, items-start, justify-between, gap-4
```

**When adding a new component:**

1. Check the library for a matching pattern
2. Create a `ui_library/<component_name>.yml` entry
3. Set `library_source` to the library path if adapted, or `null` if custom
4. List the design tokens and Tailwind classes used

## Project Design System

### CSS Tokens (`app/assets/tailwind/application.css`)

| Token | Purpose |
|-------|---------|
| `--ha-bg` | Page background |
| `--ha-surface` | Card/section surfaces |
| `--ha-card` | Card background |
| `--ha-card-border` | Card border color |
| `--ha-border` | General border color |
| `--ha-text` | Primary text |
| `--ha-muted` | Secondary/meta text |
| `--ha-accent` | Primary accent (sky blue) |
| `--ha-danger` | Destructive actions (red) |
| `--ha-surface-hover` | Hover background |

### Component CSS Classes

| Class | What it provides |
|-------|-----------------|
| `ha-card` | 24px radius, border, background, shadow, hover lift |
| `ha-card-actions` | Top border + padding for card action buttons |
| `ha-button` | Rounded-full button with padding and transitions |
| `ha-button-primary` | Accent-colored button |
| `ha-button-secondary` | Muted border button |
| `ha-button-danger` | Red destructive button |
| `ha-input` | 16px radius, border, background, focus ring |
| `ha-overline` | 0.75rem, semibold, uppercase, tracking-wide, muted |
| `ha-nav-item` | Sidebar navigation item |
| `ha-rise` | Entrance animation (slide up + fade in) |
| `ha-fade-in` | Fade-in entrance animation |

### Tailwind JIT Constraint

The Docker container compiles Tailwind in JIT mode -- **only classes already used in the codebase exist in the stylesheet.** If you use a class for the first time (e.g., `p-5`, `leading-relaxed`), it will have **zero effect** until `bin/cli app rebuild` recompiles the CSS.

**Safe values already in use:**
- Padding: `p-4` (16px), `p-6` (24px)
- Gaps: `gap-2`, `gap-3`, `gap-4`
- Margins: `mt-1`, `mt-2`, `mt-3`, `mt-4`
- Spacing: `space-y-3`, `space-y-4`, `space-y-6`, `space-y-8`
- Text: `text-xs`, `text-sm`, `text-base`, `text-lg`, `text-xl`

If a new Tailwind class is needed, note: **"Requires `bin/cli app rebuild`"**.

### Component Conventions

| Convention | Value |
|-----------|-------|
| Page sections | `space-y-8` |
| Card padding | `p-6` (list cards), `p-4` (compact inline) |
| Card grid | `gap-4` |
| Section heading -> content | `space-y-6` |
| Card content groups | `space-y-4` |
| Card ID | `id: dom_id(@record)` via `Phlex::Rails::Helpers::DOMID` |
| Card overline | `p(class: "ha-overline") { "Label" }` |
| Card actions | `div(class: "ha-card-actions") { buttons }` |
| Entrance animation | `ha-rise` with staggered `animation-delay` |
| Dark mode | Class-based (`.dark`), all tokens have dual values |

### Phlex View Structure

```ruby
module Views
  module ResourceName
    class ActionName < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      # ... other helpers as needed

      def initialize(resource:)
        @resource = resource
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: "Section", title: "Title"
          ) { render_header_actions }
          render_content
        end
      end
    end
  end
end
```

## Workflow

1. **Receive UI task** (new page, new component, styling change)
2. **Search the library** for matching components
3. **Read existing project components** to match conventions
4. **Build the Phlex component** adapting library HTML to project patterns
5. **Update `ui_library/`** with the new component entry
6. **Verify with agent-browser** that it renders correctly
7. **Check for Bullet N+1 alerts** on the page (see product-review skill)

## Existing Project Components

| Component | Type | File |
|-----------|------|------|
| Sidebar | Navigation shell | `sidebar.rb` |
| NavItem | Navigation item | `nav_item.rb` |
| PageHeader | Page heading | `page_header.rb` |
| TripCard | List card | `trip_card.rb` |
| TripStateBadge | Status badge | `trip_state_badge.rb` |
| JournalEntryCard | List card | `journal_entry_card.rb` |
| CommentCard | Inline card | `comment_card.rb` |
| CommentForm | Form | `comment_form.rb` |
| ReactionSummary | Inline widget | `reaction_summary.rb` |
| ExportCard | List card | `export_card.rb` |
| ExportStatusBadge | Status badge | `export_status_badge.rb` |
| UserCard | List card | `user_card.rb` |
| AccessRequestCard | List card | `access_request_card.rb` |
| InvitationCard | List card | `invitation_card.rb` |
| TripMembershipCard | List card | `trip_membership_card.rb` |
| ChecklistCard | List card | `checklist_card.rb` |
| ChecklistItemRow | List row | `checklist_item_row.rb` |
| NoticeBanner | Feedback | `notice_banner.rb` |
| FlashToasts | Feedback | `flash_toasts.rb` |
| TripForm | Form | `trip_form.rb` |
| JournalEntryForm | Form | `journal_entry_form.rb` |
| UserForm | Form | `user_form.rb` |
| AccountForm | Form | `account_form.rb` |
| AccountDetails | Detail display | `account_details.rb` |
| InvitationForm | Form | `invitation_form.rb` |
| AccessRequestForm | Form | `access_request_form.rb` |
| TripMembershipForm | Form | `trip_membership_form.rb` |
| ChecklistForm | Form | `checklist_form.rb` |
| RodauthLoginForm | Auth form | `rodauth_login_form.rb` |
| RodauthLoginFormFooter | Auth footer | `rodauth_login_form_footer.rb` |
| RodauthEmailAuthRequestForm | Auth form | `rodauth_email_auth_request_form.rb` |
| RodauthFlash | Auth feedback | `rodauth_flash.rb` |
