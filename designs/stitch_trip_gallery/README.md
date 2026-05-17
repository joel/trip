# Stitch — Trip Gallery + Lightbox (design reference)

**Stitch project:** `Catalyst` (`projects/3314239195447065678`)
**Applied design system:** `Catalyst Glass` (`assets/3c209c99f89947168c4e8320f9465cdc`, v1) —
the established `--ha-*` token system the app already ships. `Nomad Archive`
(`assets/c8f70ca399b44db69bafcfd7aed25bb8`) is the alternate, **not** used.

## MCP interaction performed (Phase 22 task 2)

1. `list_projects` → located the `Catalyst` project.
2. `list_design_systems` → captured the full **Catalyst Glass** spec and every
   named colour token (see below).
3. `generate_screen_from_text` for the Gallery (DESKTOP) with
   `designSystem=assets/3c209c99f89947168c4e8320f9465cdc` applied — input brief:
   `prompts/Phase 22 - Image Experience - Google Stitch Prompt.md`.
   The call returned an async timeout (documented Stitch behaviour:
   "can take a few minutes… DO NOT RETRY"); polling `list_screens` did not show
   a persisted Gallery/Lightbox screen within the session window.

## Decision (per plan §14)

The plan states: *"If the design and the established token system conflict, the
token system wins and the divergence is noted here."* Since the live screen did
not materialise in-session, the Gallery + Lightbox are implemented from the
**authoritative applied design system** (Catalyst Glass, captured below) and its
**canonical in-repo realisation** — the Phase 21 Activity page
(`app/views/audit_logs/…`, the closest "new per-trip internal page" sibling: it
defines the header overline + title + "Back to trip" + shell), and the existing
journal-entry photo grid (`app/components/journal_entry_card.rb#render_images`).
No visual invention: only `ha-card`, `ha-overline`, `ha-button*` and `--ha-*`
tokens are used. If the Stitch screen materialises later it can be reconciled in
a follow-up; structure was specified up front in the brief so divergence risk is
low.

## Catalyst Glass — token + rule summary (authoritative)

- **Fonts:** Space Grotesk (display/headline/label), Inter (body), JetBrains
  Mono (IDs/data). `--ha-*` prefixed CSS variables; class strategy dark mode.
- **No-line rule:** no `1px solid` section borders — separate via surface tier
  shifts and spacing. Cards: `radius lg`, `surface_container_lowest` on
  `surface_container_low`, no border.
- **Overlays / glass:** elevated overlays = `surface_bright` @ 80% +
  `backdrop-blur 12px` (30px in dark mode); pill buttons with primary→
  primary_container gradient; `cubic-bezier(0.4,0,0.2,1)` transitions.
- **Imagery:** photos are the heart of the system; `radius lg`; overlay text
  on images via glassmorphism chips; generous breathing room.
- **Key colours (light):** `primary #00668a`, `primary_container #38bdf8`,
  `on_primary #ffffff`, `surface #faf8ff`, `surface_container_low #f2f3ff`,
  `surface_container_lowest #ffffff`, `on_surface #131b2e`,
  `on_surface_variant #3e484f`, `outline_variant #bdc8d1`.

These map onto the app's existing `--ha-*` custom properties and `ha-*` class
families (the project's compiled realisation of this same system).
