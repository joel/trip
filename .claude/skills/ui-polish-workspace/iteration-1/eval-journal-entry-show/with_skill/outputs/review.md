## UI Polish Review -- Journal Entry Show Page

**Files reviewed:**
- `app/views/journal_entries/show.rb`
- `app/components/reaction_summary.rb`
- `app/components/comment_card.rb`
- `app/components/comment_form.rb`
- `app/components/page_header.rb`
- `app/assets/tailwind/application.css`

---

### Spatial Composition: Weak

- **Flat vertical stacking with no hierarchy breaks.** The page is a pure `space-y-8` column: header, details card, body card, image grid, reactions card, comments section. Every section occupies the same visual weight and column width. There is no variation in width, indentation, or alignment to signal which content is primary (the body/images) versus secondary (reactions, metadata). The eye has no anchor point beyond reading order.

- **Reaction bar and comments occupy equal visual weight to the entry body.** The reaction summary sits in its own `ha-card p-4` -- the same card treatment as the entry details and body. This elevates a lightweight interaction element to the same stature as the main content. Reactions should feel subordinate: either flush inline below the body card, or a borderless row tucked between body and comments.

- **Image grid lacks height constraint.** Images use `object-cover` but have no `aspect-ratio` or fixed height. With mixed-dimension photos, the grid will produce unpredictable row heights -- some cells tall, some short -- creating a ragged layout. A consistent `aspect-[4/3]` or `aspect-square` would stabilize the grid.

- **No empty state for comments.** When there are zero comments, the "Comments" heading renders above an empty `div` followed by the form. This creates an awkward gap. A quiet empty state ("No comments yet -- be the first.") would fill the void intentionally.

- **Recommendation (moderate):** Break the page into a primary content zone (body + images, wider or visually dominant) and a secondary metadata/interaction zone (reactions, comments). Consider removing the `ha-card` wrapper from the reaction summary and instead rendering it as a borderless pill row directly beneath the body card, separated by a `mt-4` rather than `space-y-8`. Add `aspect-[4/3]` to the image grid cells. Add a comments empty state.

---

### Typography: Adequate

- **PageHeader hierarchy is strong.** The section label uses `text-xs font-semibold uppercase tracking-[0.2em]` (micro label), the title is `text-3xl font-semibold tracking-tight`, and the subtitle is `text-sm text-muted`. This is a well-constructed three-tier hierarchy.

- **Comments heading breaks the established pattern.** The "Comments" heading uses `text-lg font-semibold text-[var(--ha-text)]` -- a mid-weight heading that doesn't match the section label pattern used in PageHeader (`text-xs uppercase tracking-[0.2em]`). The trips show page uses `text-xl font-semibold` for "Journal Entries". Neither follows the micro-label pattern established in PageHeader's section field. This inconsistency weakens the type system.

- **Comment body is `text-sm` while entry description is default size.** In the details card, `@entry.description` renders at default body size (no explicit size class), but comment bodies render at `text-sm`. This is reasonable for the comment/description distinction, but the description in the details card should get an explicit `text-base` or `text-sm` for clarity rather than relying on the inherited default.

- **Reaction count text (`text-xs ml-1`) is undersized.** The count beside each emoji is `text-xs` with a `ml-1` gap. At this size, single digits are legible but feel vestigial. A `text-sm font-medium` with `ml-1.5` would make counts feel like first-class data.

- **Recommendation (one-liner to moderate):** Standardize section headings within show pages -- either adopt the `text-xs uppercase tracking-[0.2em]` micro-label pattern for "Comments" (matching PageHeader's section style), or create a shared sub-section heading convention. Bump reaction counts to `text-sm font-medium`.

---

### Color & Contrast: Adequate

- **Reaction active state uses hardcoded blue values.** The active reaction button uses `border-blue-300 bg-blue-50 dark:border-blue-600 dark:bg-blue-900/30` -- raw Tailwind blue, not the design system's `--ha-accent` (sky-400). This creates a subtle but visible inconsistency. The active pill should use `border-[var(--ha-accent)]/30 bg-[var(--ha-accent)]/10` to stay within the token system. In dark mode, the hardcoded `blue-900/30` may clash with the sky-blue accent used everywhere else.

- **Delete button in CommentCard uses raw red.** The delete text is `text-red-500 hover:text-red-700` -- raw Tailwind red, not `--ha-danger`. While visually similar, it diverges from the token system. Using `text-[var(--ha-danger)] hover:text-[var(--ha-danger-strong)]` would ensure consistency if the palette ever shifts.

- **Location text in details card is `text-sm text-[var(--ha-muted)]`.** This is correct and consistent. No issue.

- **Body card `prose dark:prose-invert` may conflict with `--ha-text`.** The Tailwind prose plugin applies its own text color. The `dark:prose-invert` class handles dark mode, but the prose base gray may not exactly match `--ha-text` (slate-900 vs prose's gray-700). This can create a subtle color mismatch between the body card and the details card above it.

- **Recommendation (one-liner):** Replace hardcoded `blue-*` in `ReactionSummary#active_class` with `--ha-accent`-derived values. Replace `text-red-500` in `CommentCard` with `text-[var(--ha-danger)]`. Consider adding `text-[var(--ha-text)]` to the prose div to override the prose default text color.

---

### Shadows & Depth: Weak

- **Every section uses the same elevation.** The details card, body card, and reaction summary all carry `ha-card` which applies `--ha-card-shadow` equally. This flat shadowscape makes the page feel like a vertical list of same-level containers rather than a layered composition. The entry body (the primary content) should feel slightly elevated compared to metadata.

- **Comment cards have no shadow at all.** `CommentCard` uses `rounded-lg bg-[var(--ha-surface)] p-4` with no shadow and no border. While this correctly positions comments as subordinate to `ha-card` elements, the complete absence of depth makes them feel flat and disconnected -- especially in light mode where `--ha-surface` (#fff) matches `--ha-card` (#fff).

- **Image grid has no container shadow or card treatment.** The image grid floats as raw `<img>` tags in a grid div with no background, border, or shadow. It's the only major content section without a card wrapper, which either feels intentionally lightweight or accidentally un-styled depending on the number of images.

- **No hover elevation on reaction buttons.** The reaction pills have `hover:bg-[var(--ha-surface-hover)]` for the inactive state, but no `hover:shadow-*` or `hover:translateY(-1px)` like `ha-button` provides. This makes them feel static compared to the action buttons in the header.

- **Recommendation (moderate):** Add a subtle `shadow-sm` or `border border-[var(--ha-border)]` to comment cards to give them a whisper of depth. Consider wrapping the image grid in a card container or adding individual `shadow-md rounded-xl overflow-hidden` treatments to each image cell. Add a subtle hover lift to reaction pills (`transition transform hover:-translate-y-px`). Consider differentiating the body card with a slightly stronger shadow or a `ring-1 ring-[var(--ha-accent)]/5` to mark it as the primary content.

---

### Borders & Dividers: Adequate

- **Card borders are consistent via `ha-card`.** The details card, body card, and reaction summary all inherit `border: 1px solid var(--ha-card-border)` from the `ha-card` class. This is correct.

- **Comment cards have no border.** `CommentCard` uses only `bg-[var(--ha-surface)]` with `rounded-lg` -- no border. In dark mode, where `--ha-surface` is `#0f172a` and `--ha-bg` is `#0b1120`, the subtle difference is enough. But in light mode, where both are white, comment cards will be invisible against a white background unless the parent section has a different background. If comments live inside a `space-y-4` div with no card wrapper, they will visually merge into the page background.

- **No section dividers between major content blocks.** The page relies entirely on `space-y-8` gap for visual separation between details, body, images, reactions, and comments. A subtle `border-t border-[var(--ha-border)]` between the primary content zone (body/images) and the interaction zone (reactions/comments) could create a clearer content/interaction boundary.

- **Reaction pills border treatment is good.** Inactive pills use `border-[var(--ha-border)]` (token-consistent) and active pills use `border-blue-300` (not token-consistent -- see Color section). The rounded-full shape with a thin border creates a clean pill aesthetic.

- **Recommendation (one-liner to moderate):** Add `border border-[var(--ha-border)]` to `CommentCard` for light-mode visibility. Consider a horizontal rule or background color shift between the body/images zone and the reactions/comments zone.

---

### Transitions & Motion: Weak

- **No entrance animations on the page.** The show page renders all sections statically. The sidebar uses `ha-rise` with staggered `animation-delay` for a polished reveal sequence, but the journal entry show page has no equivalent. Given the page has 5+ distinct sections, a staggered `ha-fade-in` on each section would create a natural content reveal.

- **No hover transitions on comment cards.** `CommentCard` has no `transition` class and no hover state. Comments are static rectangles. A `transition-colors duration-150 hover:bg-[var(--ha-surface-muted)]` would make them feel responsive to interaction.

- **Reaction buttons lack transition.** The inactive reaction class has `hover:bg-[var(--ha-surface-hover)]` but no `transition` property, so the background change will be instant rather than smooth. Adding `transition-all duration-150` would align with the 150ms interaction timing used elsewhere.

- **Delete actions have no transition.** The "Delete" button in `CommentCard` uses `text-red-500 hover:text-red-700` with no transition, creating a hard color snap. The "Delete" button in the header uses `ha-button ha-button-danger` which does have transitions via the `.ha-button` class -- this inconsistency means some deletes animate and others don't.

- **`prefers-reduced-motion` is respected globally** in `application.css`, which is good. Any new animations added should be covered by the existing `@media (prefers-reduced-motion: reduce)` rule, though it only targets `ha-fade-in`, `ha-rise`, and `ha-button` currently. New transition utilities would need to be added.

- **Recommendation (moderate):** Add `ha-fade-in` with staggered delays to each major section in the show page (details, body, images, reactions, comments). Add `transition-all duration-150` to reaction pill classes. Add `transition-colors duration-150` to comment cards with a hover background shift. Update the `prefers-reduced-motion` media query to cover any new animated elements.

---

### Micro-Details: Weak

- **Image alt text is generic.** Every image in the grid uses `alt: @entry.name` -- the entry title repeated for every image. This is neither descriptive nor accessible. If images have individual filenames or captions, those should be used. At minimum, append an index: `"#{@entry.name} - photo #{index + 1}"`.

- **Inconsistent border radius in comment cards.** The project's border radius language is: 24px (cards), 16px (inputs), 999px (buttons/pills), 2xl (nav items), xl (small containers). `CommentCard` uses `rounded-lg` (8px) which doesn't match any tier in the established radius language. It should be `rounded-xl` (12px) to match the "small containers" tier, or `rounded-2xl` (16px) to match the input tier.

- **No cursor pointer on reaction buttons.** The reaction buttons are `button_to` forms, so they should inherit cursor-pointer from the `<button>` element. However, the explicit styling doesn't include `cursor-pointer`, and depending on the form wrapper styling, this might not be visually obvious. Worth verifying.

- **`unsafe_raw` in body rendering.** The body section uses `unsafe_raw @entry.body.to_s` which renders raw HTML. This is a functional concern (sanitization) more than a polish concern, but from a visual standpoint, the raw HTML may contain elements that don't inherit the project's font stack (Space Grotesk). The `prose` class helps, but any inline styles in the rich text could override it.

- **Reaction emoji `span` has no aria-label.** Each emoji button renders `span { EMOJI_DISPLAY[emoji] }` -- the unicode emoji character. Screen readers may announce these inconsistently. An `aria-label` on the button (e.g., `aria_label: "React with #{emoji}"`) would improve semantics, though this borders on ux-review territory.

- **Comment form textarea and button alignment.** The form uses `flex gap-3` with the textarea in `flex-1` and the submit button in `flex items-end`. The button aligns to the bottom of the textarea, which is correct for a 2-row textarea. But if the textarea grows (e.g., auto-resize on input), the button will drop to the bottom. Consider `items-start` with a `mt-auto` fallback, or pinning the button with `self-end`.

- **Recommendation (one-liner to moderate):** Change `rounded-lg` to `rounded-xl` in `CommentCard`. Add indexed alt text to images. Add `aria_label` to reaction buttons. Verify cursor states on reaction pills.

---

### CSS Architecture

- **Reaction pill classes should be extracted.** The `active_class` and `inactive_class` methods in `ReactionSummary` each define 6-8 Tailwind utilities that represent a semantic concept ("reaction pill" in active/inactive states). This pattern appears only in this component currently, but the pill button concept (rounded-full, bordered, small padding, inline-flex) recurs conceptually in tags and badges. A candidate for `ha-pill` and `ha-pill-active` component classes in `application.css`.

- **Comment card surface styling is a candidate for extraction.** The `CommentCard` uses `flex gap-3 rounded-lg bg-[var(--ha-surface)] p-4` -- a surface-level container pattern that also appears in `ChecklistItemRow` (`flex items-center gap-3 rounded-lg bg-[var(--ha-surface)]`). This "surface row" pattern appears 2-3 times and is approaching the extraction threshold. A `ha-surface-row` or `ha-list-item` class could unify these.

- **`hover:bg-[var(--ha-surface-hover)]` references a missing token.** The `ReactionSummary#inactive_class` uses `hover:bg-[var(--ha-surface-hover)]` but `--ha-surface-hover` is not defined in `application.css`. This means the hover background will resolve to `transparent` or the initial value, making the hover state invisible. This is a bug. Define `--ha-surface-hover` in both light (e.g., `#f1f5f9`) and dark (e.g., `#1e293b`) modes in `application.css`.

- **Hardcoded colors should migrate to tokens.** `ReactionSummary#active_class` uses `border-blue-300 bg-blue-50 dark:border-blue-600 dark:bg-blue-900/30` and `CommentCard` uses `text-red-500 hover:text-red-700`. These should use `--ha-accent` and `--ha-danger` derived values respectively.

---

### Screenshots Reviewed

- Code-based review only (agent-browser not available). No live screenshots were taken. The following viewports/themes were **not** visually verified:
  - Desktop light mode
  - Desktop dark mode
  - Mobile (375px) light mode
  - Mobile (375px) dark mode

All observations are derived from structural code analysis against the project's design system tokens and patterns. A live visual pass is recommended to confirm shadow rendering, dark-mode contrast ratios, and image grid behavior with real content.

---

### Summary of Findings by Effort

| # | Finding | Effort | Dimension |
|---|---------|--------|-----------|
| 1 | Missing `--ha-surface-hover` CSS token (bug) | One-liner | CSS Architecture |
| 2 | Hardcoded `blue-*` in reaction active state | One-liner | Color |
| 3 | Hardcoded `text-red-500` in comment delete | One-liner | Color |
| 4 | `rounded-lg` should be `rounded-xl` in CommentCard | One-liner | Micro-Details |
| 5 | Add `transition-all duration-150` to reaction pills | One-liner | Transitions |
| 6 | Missing `aspect-[4/3]` on image grid cells | One-liner | Spatial |
| 7 | Add `border border-[var(--ha-border)]` to CommentCard | One-liner | Borders |
| 8 | Indexed alt text for images | One-liner | Micro-Details |
| 9 | Add `transition-colors duration-150` + hover to CommentCard | One-liner | Transitions |
| 10 | Empty state for zero comments | Moderate | Spatial |
| 11 | Staggered `ha-fade-in` entrance animations | Moderate | Transitions |
| 12 | Standardize section headings (Comments, etc.) | Moderate | Typography |
| 13 | Demote reaction summary from card to inline pill row | Moderate | Spatial |
| 14 | Extract `ha-pill` / `ha-pill-active` CSS classes | Moderate | CSS Architecture |
| 15 | Differentiate shadow layers for primary vs secondary content | Significant | Shadows |

Want me to apply these fixes?
