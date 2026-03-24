# UI Library

Project component registry that maps each Phlex component to its source in the [Tailwind CSS UI Components Library](~/Workspace/WebUIComponents/TailwindCSS/).

Each `.yml` file documents one project component: what library pattern it was adapted from (or if it's custom), which design tokens it uses, and which Tailwind classes it relies on.

## How to Use

**Before building a new component**, check this directory for existing components that solve the same problem. Then search the reference library:

```bash
ls ~/Workspace/WebUIComponents/TailwindCSS/application_ui/<category>/
```

**After building a component**, create a `.yml` entry here to keep the registry in sync.

## File Format

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
