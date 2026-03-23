# UI Polish Review -- Phase 6: Export Architecture + Workflow Completion

Branch: `feature/export-architecture`

## Files Reviewed

- `app/views/exports/index.rb`
- `app/views/exports/new.rb`
- `app/views/exports/show.rb`
- `app/components/export_card.rb`
- `app/components/export_status_badge.rb`
- `app/views/trips/show.rb` (Exports button addition)
- `app/components/sidebar.rb` (exports controller added to Trips active state)
- `app/assets/tailwind/application.css` (reference for design tokens)

Reference components compared against:
- `app/components/trip_card.rb`
- `app/components/trip_state_badge.rb`
- `app/components/journal_entry_card.rb`
- `app/components/page_header.rb`

---

## Spatial Composition: Adequate

**Observations:**

- The exports index, show, and new pages all use `space-y-6` as their top-level wrapper spacing. Every other page in the application (trips/show, users/index, users/show, invitations/index, access_requests/index, journal_entries/show, accounts/show, welcome/home, and all Rodauth views) uses `space-y-8`. This creates an inconsistent vertical rhythm -- export pages feel slightly more compressed than the rest of the app without a clear design rationale.

- The ExportCard uses `ha-card p-4` while virtually every other card component (TripCard, JournalEntryCard, UserCard, AccessRequestCard, InvitationCard, TripMembershipCard, ChecklistCard) uses `ha-card p-6`. The only other `p-4` card is the ReactionSummary component, which is intentionally compact as an inline widget. ExportCard is a list-level card and should match the padding convention.

- The export show page detail rows use `flex items-center justify-between` -- a clean key/value layout. This works but is visually flat; there is no structural break between the status badge row and the text rows. A subtle divider or grouped sections could add hierarchy.

- The "Back to exports" link on the new export page sits in its own `div(class: "flex flex-wrap gap-2")` wrapper below the card. This is disconnected from the form card. In contrast, the trip show page groups all action buttons in the PageHeader block. The back link would feel more cohesive inside the form card or the page header.

**Recommendations:**

1. Change all three export views from `space-y-6` to `space-y-8` to match the app-wide convention. **[one-liner]**
2. Change ExportCard from `ha-card p-4` to `ha-card p-6` to match all other list cards. **[one-liner]**
3. Move the "Back to exports" link in `new.rb` into the PageHeader block, matching the pattern used in `show.rb`. **[moderate]**

---

## Typography: Adequate

**Observations:**

- ExportCard uses `text-sm font-medium` for the title ("Markdown Export"). TripCard uses `text-lg font-semibold` for the title. The export title reads smaller and lighter than its equivalent in other cards, which weakens hierarchy.

- ExportCard has no overline label. Every other card component uses `ha-overline` (e.g., TripCard says "Trip", UserCard says "User", AccessRequestCard says "Access Request"). The ExportCard jumps straight to the title, breaking the established card typography pattern.

- The format icon in ExportCard uses plain text "MD" / "EP" at default size. These abbreviations are functional but typographically anonymous -- no explicit font weight, size, or tracking is applied. They could use JetBrains Mono (the project's code/mono font) with `font-mono text-xs font-semibold tracking-wider` to give them more visual identity.

- The export show page detail labels use `text-sm text-[var(--ha-muted)]` and values use `text-sm font-medium text-[var(--ha-text)]`. This is a reasonable key/value pairing, but the labels and values are the same text size, making scanning harder than it needs to be. A size differential (e.g., `text-xs` for labels) would improve scanability.

**Recommendations:**

4. Add `p(class: "ha-overline") { "Export" }` to ExportCard before the title, matching the TripCard pattern. **[one-liner]**
5. Increase ExportCard title from `text-sm font-medium` to `text-base font-semibold` or `text-lg font-semibold` to match TripCard. **[one-liner]**
6. Apply `font-mono text-xs font-semibold tracking-wider` to the format icon text ("MD" / "EP"). **[one-liner]**
7. In export show, change detail row labels from `text-sm` to `text-xs` for better key/value differentiation. **[one-liner]**

---

## Color & Contrast: Strong

**Observations:**

- ExportStatusBadge maps colors correctly to semantic meaning: amber for pending, sky for processing, emerald for completed, red for failed. This matches the project's status color convention exactly (same pattern as TripStateBadge).

- Both light and dark mode badge colors use the same `bg-{color}-100 text-{color}-800 dark:bg-{color}-500/10 dark:text-{color}-300` pattern as TripStateBadge. Consistent.

- The format icon uses `bg-[var(--ha-accent)]/10 text-[var(--ha-accent)]` -- accent color at 10% opacity for background with full accent for text. This is a good use of the accent palette for a non-status, informational element.

- The accent color is used appropriately and sparingly: only on the format icon and the primary action buttons. Not scattered.

**One issue -- broken token reference:**

- `exports/new.rb` line 66 uses `hover:bg-[var(--ha-bg-muted)]` as the hover background for format option labels. **This CSS custom property does not exist in the design token system.** The token `--ha-bg-muted` is not defined in `application.css` (neither in `:root` nor `.dark`). This means the hover state resolves to nothing -- no visible background change on hover. The correct token is `--ha-surface-hover`, which is what other components use (e.g., `reaction_summary.rb`, `comment_card.rb`).

**Recommendations:**

8. **(Bug fix)** Replace `hover:bg-[var(--ha-bg-muted)]` with `hover:bg-[var(--ha-surface-hover)]` in `exports/new.rb` line 66. **[one-liner, critical]**

---

## Shadows & Depth: Adequate

**Observations:**

- All export cards correctly use `ha-card`, which inherits `--ha-card-shadow` and the `-1px translateY` hover lift. This is consistent with the design system.

- The export show page detail card uses `ha-card p-6 space-y-4` -- shadow and hover behavior inherited correctly.

- In dark mode, the card shadow transitions correctly to the higher-opacity dark variant defined in `.dark .ha-card:hover`.

- No additional shadow layers are used. For these components (simple list cards and detail views), the default card shadow is appropriate -- no need for elevation hierarchy.

**No recommendations -- shadows are correctly inherited from the design system.**

---

## Borders & Dividers: Weak

**Observations:**

- ExportCard does not use `ha-card-actions` for its action buttons. It renders Download and Details buttons inline with the status badge in the same row (`div(class: "flex items-center gap-3")`). Every other card component (TripCard, JournalEntryCard, UserCard, etc.) uses `ha-card-actions`, which provides a `border-top`, `margin-top`, and `padding-top` to visually separate the action area from the card content. The export card's inline layout makes the buttons feel attached to the status badge rather than being a distinct action zone.

- The format option labels in `exports/new.rb` use `border border-[var(--ha-border)]` with `rounded-xl`. This is correct use of the token system, and `rounded-xl` (12px) is a reasonable choice inside a `rounded-[24px]` card (16px would also work per the border radius language, but 12px is acceptable for nested elements).

- The export show detail card has no internal dividers between rows. The `space-y-4` provides vertical spacing, but with 4 key/value rows of the same visual weight, the section feels like an undifferentiated list. Even a single divider (e.g., between Status and the remaining metadata) would create a content group.

**Recommendations:**

9. Refactor ExportCard to use `ha-card-actions` for the Download/Details buttons, matching the pattern of every other card. Move the status badge into the card body area (next to the title or below the timestamp). **[moderate]**
10. In the new export form, consider using `has-[:checked]:border-[var(--ha-accent)] has-[:checked]:bg-[var(--ha-accent)]/5` on the format option labels so the selected radio option gets a visual highlight via border color change. Currently the only selected-state indicator is the radio dot itself. **[moderate]**

---

## Transitions & Motion: Weak

**Observations:**

- No entrance animations (`ha-rise` or `ha-fade-in`) are applied to any export component or view. The trips show page, welcome/home page, and sidebar all use `ha-rise` with staggered `animation-delay` to create a sequential reveal. Export pages render all content simultaneously with no animation, making them feel static compared to the rest of the app.

- The ExportCard inherits the `ha-card` hover transition (translateY + shadow) through the CSS class. This works correctly.

- The format option labels in `new.rb` have `transition` but no specific transition property is declared beyond what the browser infers. Adding `transition-colors` or `transition-all` would make the intent explicit.

- No loading/processing state animation. When an export has `processing` status, there is no visual indication of activity (spinning, pulsing, etc.). The badge just says "Processing" in static text. A subtle pulse animation on the processing badge would communicate that something is happening.

**Recommendations:**

11. Add `ha-rise` to export cards in the index view with staggered `animation-delay` per card (e.g., 40ms increments). **[moderate]**
12. Add `ha-fade-in` to the detail card in `exports/show.rb`. **[one-liner]**
13. Add a CSS pulse animation for the `processing` status badge: `animate-pulse` on the badge span when status is `processing`. **[one-liner]**
14. Change `transition` to `transition-colors` on the format option labels for explicit intent. **[one-liner]**

---

## Micro-Details: Weak

**Observations:**

- **Missing `dom_id`**: ExportCard does not set `id: dom_id(@export)` on its root element. Every other card component in the project (TripCard, JournalEntryCard, UserCard, AccessRequestCard, InvitationCard, TripMembershipCard) uses `dom_id` for Turbo Stream targeting. Even if exports do not currently use Turbo Streams, omitting `dom_id` breaks the convention and makes future Turbo Stream integration harder.

- **Format icon rounding inconsistency**: The format icon uses `rounded-xl` (12px) inside an `ha-card` (24px radius). While acceptable, the sidebar nav icons use `rounded-xl` inside `rounded-2xl` containers. The icon container would feel more cohesive at `rounded-2xl` (16px) to echo the sidebar icon treatment and sit more naturally inside the 24px card.

- **No `checked` state for radio buttons**: The radio button styling relies on browser defaults with only `accent-[var(--ha-accent)]` applied. There is no visual feedback on the parent label when a radio is selected (no border color change, no background tint). This means users must look for the small radio dot to know which option is active. Other design systems typically highlight the entire option card on selection.

- **Button sizing in ExportCard**: The Download and Details buttons use `text-xs` override on `ha-button` class buttons. No other card in the app applies `text-xs` to its action buttons -- they all use the default `ha-button` font size (0.875rem / text-sm). This makes export card buttons noticeably smaller than buttons in other cards.

- **"Back to trip" button placement**: On the exports index page, "Back to trip" is a header action button alongside "New export". This is correct and matches the pattern in `trips/show.rb` where "Back to trips" is a header action. Good.

**Recommendations:**

15. Add `include Phlex::Rails::Helpers::DOMID` and `id: dom_id(@export)` to ExportCard, matching every other card. **[one-liner]**
16. Change format icon from `rounded-xl` to `rounded-2xl` for consistency with sidebar icon containers. **[one-liner]**
17. Remove `text-xs` from ExportCard action buttons so they match the default `ha-button` size. **[one-liner]**
18. Add selected-state styling to format option labels (see recommendation 10). **[moderate]**

---

## CSS Architecture

**Issues found:**

- **Undefined token `--ha-bg-muted`** used in `exports/new.rb`. Must be replaced with `--ha-surface-hover` or a new token must be defined. Since `--ha-surface-hover` already serves this purpose and is used by other components, use that. **(Critical bug -- hover state is silently broken.)**

- The ExportStatusBadge and TripStateBadge have nearly identical structures: both use `rounded-full px-3 py-1 text-xs font-medium` with a color map hash. This pattern appears twice and could be extracted into a shared base class or a generic `ha-badge` CSS component. However, with only 2 occurrences, this is borderline -- extraction would be warranted if a third badge type appears.

- The format option label styling in `new.rb` (`flex cursor-pointer items-start gap-3 rounded-xl border border-[var(--ha-border)] p-4 transition hover:bg-[var(--ha-surface-hover)]`) is 9 utilities long. If radio card options appear elsewhere, this should be extracted to an `ha-option-card` class. For now with a single use, inline is acceptable.

- No new CSS classes need extraction at this point. The export components correctly use existing `ha-card`, `ha-button`, `ha-button-primary`, `ha-button-secondary`, and `ha-overline` classes.

---

## Screenshots Reviewed

| Page | Viewport | Theme |
|------|----------|-------|
| Exports index | Desktop (1280x900) | Light |
| Exports index | Desktop (1280x900) | Dark |
| Exports index | Mobile (375x812) | Light |
| Export show | Desktop (1280x900) | Light |
| Export show | Desktop (1280x900) | Dark |
| Export show | Mobile (375x812) | Light |
| Export new | Desktop (1280x900) | Light |
| Export new | Desktop (1280x900) | Dark |
| Export new | Mobile (375x812) | Light |
| Trip show (with Exports button) | Desktop (1280x900) | Light |
| Trips index (reference) | Desktop (1280x900) | Light |

---

## Summary of Recommendations

### Critical (bug)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 8 | Replace undefined `--ha-bg-muted` with `--ha-surface-hover` | `exports/new.rb:66` | one-liner |

### High Priority (convention alignment)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 1 | Change `space-y-6` to `space-y-8` in all export views | `exports/index.rb`, `new.rb`, `show.rb` | one-liner |
| 2 | Change ExportCard padding from `p-4` to `p-6` | `export_card.rb:14` | one-liner |
| 4 | Add `ha-overline` label ("Export") to ExportCard | `export_card.rb` | one-liner |
| 9 | Use `ha-card-actions` for ExportCard buttons | `export_card.rb` | moderate |
| 15 | Add `dom_id(@export)` to ExportCard root element | `export_card.rb` | one-liner |
| 17 | Remove `text-xs` from ExportCard action buttons | `export_card.rb:57-58` | one-liner |

### Medium Priority (polish)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 3 | Move "Back to exports" link to PageHeader in new.rb | `exports/new.rb` | moderate |
| 5 | Increase ExportCard title to `text-base font-semibold` or larger | `export_card.rb:19` | one-liner |
| 6 | Apply `font-mono text-xs font-semibold tracking-wider` to format icon | `export_card.rb:46` | one-liner |
| 10 | Add `has-[:checked]` border/bg highlight to radio labels | `exports/new.rb` | moderate |
| 11 | Add `ha-rise` with staggered delay to export cards | `exports/index.rb` | moderate |
| 16 | Change format icon from `rounded-xl` to `rounded-2xl` | `export_card.rb:42` | one-liner |

### Low Priority (nice-to-have)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 7 | Use `text-xs` for detail row labels in show page | `exports/show.rb:72` | one-liner |
| 12 | Add `ha-fade-in` to detail card in show page | `exports/show.rb:48` | one-liner |
| 13 | Add `animate-pulse` to processing status badge | `export_status_badge.rb` | one-liner |
| 14 | Change `transition` to `transition-colors` on radio labels | `exports/new.rb:66` | one-liner |

---

## Overall Assessment

The export UI is **functionally correct and visually coherent** -- it reads as part of the same app and uses the design token system appropriately. However, it does not yet match the **craft level** of the reference components (TripCard, JournalEntryCard). The main gaps are:

1. **Convention drift** -- `space-y-6` vs `space-y-8`, `p-4` vs `p-6`, missing `ha-overline`, missing `dom_id`, missing `ha-card-actions`. These are small individually but collectively make the export components feel like they were built by someone who understood the design system's *vocabulary* but not its *grammar*.

2. **No entrance animation** -- the rest of the app has `ha-rise` and staggered delays that create a sense of considered choreography. Export pages are static by comparison.

3. **One broken token** -- `--ha-bg-muted` does not exist, causing the format option hover state to silently fail. This is the only actual bug.

Want me to apply these fixes?
