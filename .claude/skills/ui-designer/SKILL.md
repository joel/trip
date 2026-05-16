---
name: ui-designer
description: Build production-grade frontend interfaces using Tailwind CSS, Phlex components, and Hotwire (Turbo + Stimulus). Use this skill whenever the user asks to build, style, or improve web pages, UI components, layouts, forms, navigation, dashboards, or any visual frontend element. Also use when the user mentions designing a view, creating a Phlex component, styling with Tailwind, adding a sidebar, building a table, creating a card, or beautifying any web UI. This skill has access to a 657-component reference library to produce polished, consistent results. Always trigger this skill for ANY UI-related work -- even small styling tweaks, layout adjustments, or "make this look better" requests.
compatibility: Rails project with Phlex (Components::Base) + Tailwind CSS standalone (no Node/npm) + Hotwire (Turbo + Stimulus). Requires a local clone of the Tailwind UI component library at ~/Workspace/WebUIComponents/TailwindCSS/ and the project-local ui_library/*.yml registry.
---

# UI Designer

Build and modify frontend interfaces for this Rails + Phlex + Tailwind project. Every UI change must go through this skill to ensure consistency with the design system and reuse of existing library components.

## Component Reference Library

This skill draws from a local library of 657 Tailwind CSS component templates (path documented in the `compatibility` frontmatter). Before building any non-trivial UI element, read `references/component_library.md` — it has the full category index (364 Application UI + 114 E-commerce + 179 Marketing), the decision flow for picking a template, the Phlex translation example, and how to browse and regenerate the project index.

If the library path is missing on this machine, stop and ask the user rather than inventing class names.

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

**Verify each class is already compiled before you use it.** Do not trust a
static "safe list" — the compiled set changes every time a component is
added or removed. Probe the candidate classes you intend to use against the
actual source (`app/components` + `app/views`):

```bash
# Returns USED(n) if the class already appears in a view/component
# (hence compiled), or —ABSENT— if using it requires a rebuild.
probe() { c="$1"; n=$(grep -rEl "(^|[\" ])$c([\" ]|$)" app/components app/views 2>/dev/null | wc -l); printf "%-20s %s\n" "$c" "$([ "$n" -gt 0 ] && echo "USED($n)" || echo "—ABSENT—")"; }
for c in p-5 w-2 h-3 ring-2 border-l "top-1/2" leading-relaxed; do probe "$c"; done
```

Treat `—ABSENT—` classes as unavailable: either pick a compiled
equivalent, or, if a genuinely new class is unavoidable, use it and note
**"Requires `bin/cli app rebuild`"** in your report so the rebuild +
visual re-verification happens before the change is considered done.

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

Run `ls app/components/*.rb` to see the current set — match the naming and structural conventions of the existing files when adding new ones. (Intentionally not listed inline: the component set changes frequently and a static list goes stale the moment a component is added or renamed.)
