# UI Designer Review -- Phase 7: PWA + Mobile Capabilities

Branch: `feature/phase-7-pwa-mobile`

## Files Reviewed

- `app/components/pwa_install_banner.rb`
- `app/javascript/controllers/pwa_controller.js`
- `app/views/layouts/application_layout.rb` (PwaInstallBanner render placement)
- `app/assets/tailwind/application.css` (reference for design tokens)
- `public/offline.html` (standalone offline fallback page)

Reference components compared against:
- `app/components/flash_toasts.rb` (nearest architectural sibling -- fixed overlay with dismiss)
- `app/components/notice_banner.rb` (feedback category)
- `app/components/access_request_card.rb` (card structure reference)
- `app/components/icons/close.rb` (icon dependency)
- `app/components/icons/base.rb` (icon base class)

Library components compared against:
- `application_ui/overlays/notifications/simple.html`
- `application_ui/overlays/notifications/with_actions_below.html`

---

## Component Architecture: Strong

**Observations:**

- PwaInstallBanner correctly extends `Components::Base` and follows the Phlex component conventions. The class is 75 lines -- well under the 500-line file limit and 100-line class limit.

- The component is decomposed into three clean private methods (`render_icon`, `render_content`, `render_dismiss_button`), each under 20 lines with a single responsibility. This matches the FlashToasts decomposition pattern exactly.

- The Stimulus controller binding is correct: the outer `div` binds `data-controller="pwa"`, the inner div binds `data-pwa-target="banner"`, the install button binds `data-action="pwa#install"`, and the dismiss button binds `data-action="pwa#dismiss"`. All four Stimulus data attributes are properly wired.

- The component is rendered in `application_layout.rb` at line 23, immediately after `FlashToasts` and before the sidebar/main layout wrapper. This is the correct placement for a fixed-position overlay -- it sits outside the flex layout so it doesn't affect document flow.

- The component uses `Components::Icons::Close` correctly, passing `css: "h-3.5 w-3.5"` to override the default icon size. This matches the exact same pattern used in `FlashToasts#render_dismiss_button`.

**No recommendations -- the component architecture is solid.**

---

## Spatial Composition: Strong

**Observations:**

- The outer wrapper uses `fixed bottom-6 right-6 z-50`. FlashToasts uses `fixed right-6 top-6 z-50`. These two overlays are positioned on opposite vertical edges (bottom vs top) of the same side, which avoids overlap. The `z-50` value matches, so neither will stack incorrectly over the other. This is well considered.

- The inner banner uses `p-4` padding, matching the compact inline component convention (ReactionSummary, CommentCard). Since this is a floating notification rather than a list card, `p-4` is the correct choice -- `p-6` would make the banner feel oversized for its role.

- The icon container uses `h-9 w-9` which matches the FlashToasts icon container dimensions exactly. The content area uses `min-w-0 flex-1` -- the same pattern as FlashToasts. The dismiss button uses `h-7 w-7` -- again, identical to FlashToasts. This dimensional consistency means the two overlays share the same visual rhythm.

- `max-w-sm` constrains the banner width, matching the FlashToasts container width constraint. The banner will not sprawl on wide viewports.

- The `gap-3` between icon, content, and dismiss button matches FlashToasts. Internal content spacing uses `mt-1` (description below title) and `mt-2` (install button below description), which creates a clear hierarchy: tighter coupling between title and description, slightly more space before the action.

**No recommendations -- spatial composition is consistent with the FlashToasts overlay pattern.**

---

## Typography: Adequate

**Observations:**

- The title "Install Trip Journal" uses `text-sm font-semibold`. FlashToasts uses `text-sm font-semibold` for its titles ("All set", "Action needed"). This is a perfect match.

- The description "Add to your home screen for quick access." uses `mt-1 text-sm text-sky-100/80`. FlashToasts uses `mt-1 text-sm text-emerald-100/80` (or `text-rose-100/80`). The structure is identical; only the color hue differs. Consistent.

- The Install button uses `text-xs font-medium`. This is appropriate for a secondary action inside a compact notification. The `font-medium` weight differentiates it from the description text without competing with the title.

**One observation (not a bug):**

- The Install button text is a bare "Install" string. For accessibility and clarity, adding a visually hidden extended label or an `aria-label` attribute ("Install Trip Journal") would help screen reader users differentiate this button from other actions on the page. However, the dismiss button already has `aria_label: "Dismiss"`, and the install button's context within the banner makes its purpose clear. This is a nice-to-have, not a requirement.

**Recommendations:**

1. Consider adding `aria_label: "Install Trip Journal"` to the Install button for improved screen reader context, matching the `aria_label` pattern already on the dismiss button. **[one-liner, low priority]**

---

## Color & Contrast: Strong

**Observations:**

- The banner uses a sky-blue color palette: `border-sky-300/30`, background gradient using `rgba(56,189,248,0.12)` (which is `--ha-accent` at 12% opacity), `text-sky-100`, `text-sky-200`. The `--ha-accent` value is `#38bdf8` (sky-400), so the banner's color language is directly derived from the project's accent color. This is semantically appropriate -- the install prompt is a positive, informational action that should use the accent color.

- FlashToasts uses emerald for success and rose for alerts. The PwaInstallBanner uses sky for information/promotion. This creates a clear semantic color distinction: green = success, red = alert, blue = informational prompt. No color collision.

- The gradient `bg-[linear-gradient(140deg,rgba(56,189,248,0.12),rgba(15,23,42,0.92))]` follows the exact same pattern as FlashToasts: `bg-[linear-gradient(140deg,rgba(16,185,129,0.12),rgba(15,23,42,0.92))]`. Same angle (140deg), same dark terminus (`rgba(15,23,42,0.92)` which is `--ha-panel` at 92% opacity), different accent hue. This is excellent pattern reuse.

- The shadow `shadow-[0_18px_45px_-30px_rgba(56,189,248,0.6)]` again mirrors FlashToasts: same geometry, different color. Consistent.

- The icon container uses `bg-sky-400/20 text-sky-200`. FlashToasts uses `bg-emerald-400/20 text-emerald-200`. Same opacity and pattern, different hue. Consistent.

- The dismiss button uses `text-sky-100/80 hover:bg-sky-200/10 hover:text-sky-100`. FlashToasts uses `text-#{color}-100/80 hover:bg-#{color}-200/10 hover:text-#{color}-100`. Identical pattern.

- The Install button uses `bg-sky-500/20 hover:bg-sky-500/30 text-sky-100`. This is a ghost-style button that stays within the sky palette. It does not use `ha-button` or `ha-button-primary` classes -- this is intentional because those are full-opacity, rounded-full buttons meant for card actions. The ghost button treatment is appropriate inside a notification overlay.

**No recommendations -- color usage is consistent and semantically correct.**

---

## Shadows & Depth: Strong

**Observations:**

- The banner uses `shadow-[0_18px_45px_-30px_rgba(56,189,248,0.6)]` -- an arbitrary shadow value that creates a colored glow effect. This matches FlashToasts exactly (same geometry, different hue). The colored glow reinforces the banner's color identity and provides visual lift without looking disconnected from the design system.

- The border `border border-sky-300/30` provides a subtle edge definition at low opacity. Combined with the gradient background and shadow, this creates a "frosted glass" effect that is consistent with the FlashToasts aesthetic.

- No hover transform is applied (no `translateY` or shadow change on hover). This is correct -- the banner is a passive notification, not an interactive card. Hover effects would be misleading on the banner itself (though the buttons inside have their own hover states).

**No recommendations -- shadow and depth treatment is consistent.**

---

## Borders & Dividers: Adequate

**Observations:**

- The banner uses `rounded-2xl` for the outer container. FlashToasts also uses `rounded-2xl`. The project's `ha-card` class uses `border-radius: 24px` (which is `rounded-3xl` in Tailwind), while `rounded-2xl` is 16px. Since the banner is not using `ha-card` (it's a notification overlay, not a card), `rounded-2xl` is the correct choice -- it matches the FlashToasts rounding and is visually distinct from cards.

- The icon container uses `rounded-xl` (12px). This is consistent with FlashToasts icon containers. The dismiss button uses `rounded-full` -- consistent with FlashToasts.

- The Install button uses `rounded-lg` (8px). FlashToasts does not have an equivalent inline action button, so there is no direct precedent. `rounded-lg` is a reasonable choice for a small ghost button inside a `rounded-2xl` container -- the nesting ratio (8px inside 16px) is proportional.

**No recommendations -- border radius language is consistent.**

---

## Transitions & Motion: Weak

**Observations:**

- The banner has `transition-all duration-300 ease-out` on the inner div. This applies to all animatable properties with a 300ms duration. FlashToasts also uses `transition-all duration-300 ease-out`. Matching.

- However, the banner starts with `class: "hidden"` and the Stimulus controller removes `hidden` via `classList.remove("hidden")`. The CSS `hidden` class sets `display: none`, and `display` is not an animatable property. This means the banner will snap into view with no entrance transition -- the `transition-all` class has no effect because there is no gradual property change to animate.

- FlashToasts avoids this problem because its elements are always in the DOM (they render conditionally via Ruby's `return unless flash.any?`), so they never need to transition from `hidden` to visible. The PwaInstallBanner uses a fundamentally different show/hide mechanism (JavaScript class toggle) but does not account for the CSS transition limitation.

- No `ha-rise` or `ha-fade-in` entrance animation is used. For a bottom-positioned banner, a subtle slide-up animation would feel natural and polished. The banner could start with `opacity-0 translate-y-4` and animate to `opacity-100 translate-y-0` when shown.

- The dismiss action in the Stimulus controller adds `hidden` immediately (`this.bannerTarget.classList.add("hidden")`), so the exit is also instant -- no fade-out or slide-down.

**Recommendations:**

2. Replace the `hidden` show/hide mechanism with an opacity + transform approach. The banner should start with `opacity-0 translate-y-4 pointer-events-none` (invisible but in layout), and the Stimulus controller should toggle these classes to `opacity-100 translate-y-0 pointer-events-auto` when showing. The existing `transition-all duration-300 ease-out` will then animate the entrance smoothly. **[moderate]**

3. For the dismiss action, reverse the animation (add `opacity-0 translate-y-4`), wait for the transition to complete (300ms), then add `pointer-events-none` or `hidden`. This gives a graceful exit. **[moderate]**

4. Alternatively, add `ha-rise` to the banner element and use `display: none` / `display: flex` toggle with a small delay. However, option 2 is cleaner because it works with CSS transitions rather than CSS animations. **[alternative]**

---

## Micro-Details: Adequate

**Observations:**

- **No `id` attribute**: The banner does not have an `id` on its root element. Other overlay components like FlashToasts don't have IDs either (they're globally unique singletons), so this is acceptable for now. However, Turbo Stream updates cannot target the banner without an ID. Since the PWA banner is a global singleton, this is unlikely to matter.

- **SVG `aria_hidden: "true"`**: The download icon SVG has `aria_hidden: "true"`, which is correct -- the icon is decorative and the adjacent text provides meaning. Good accessibility practice.

- **Dismiss button `aria_label: "Dismiss"`**: Present and correct. This matches the FlashToasts dismiss button label.

- **Missing `pointer-events-none` on the outer wrapper**: FlashToasts uses `pointer-events-none` on its outer fixed container so that the transparent container area does not block clicks on the page below. The PwaInstallBanner's outer `div` (`fixed bottom-6 right-6 z-50`) does not need this because `bottom-6 right-6` positions the div to wrap tightly around its content (no stretching). However, FlashToasts uses `w-full max-w-sm` which causes its container to span a wider area. The PwaInstallBanner does not set width on the outer div, so the container collapses to content width. No issue here, but the inner div does correctly have `pointer-events-auto` in the FlashToasts pattern; here the inner div does not need it because the outer div is already non-blocking.

- **`flex-shrink-0` on the icon**: The icon container uses `flex-shrink-0` to prevent the icon from collapsing when the content area grows. This is correct and matches the same pattern used in `sidebar.rb` and `checklist_item_row.rb`.

- **Hardcoded text**: The heading ("Install Trip Journal") and description ("Add to your home screen for quick access.") are hardcoded strings. These are not passed as constructor arguments. This is appropriate -- the PWA install banner is a global singleton with fixed content. There is no reason to make it configurable.

- **`hidden` and `flex` conflict**: The inner div has `class: "hidden pointer-events-auto flex items-start gap-3 ..."`. The `hidden` class sets `display: none` and `flex` sets `display: flex`. In CSS, the last declaration wins, but Tailwind uses `!important` on the `hidden` utility (`display: none !important` in Tailwind v4). The Stimulus controller removes `hidden`, at which point `flex` takes effect. This works correctly, but combining `hidden` and `flex` in the same class list is a known Tailwind pattern that can confuse developers. An alternative is to use the opacity + pointer-events approach (see recommendation 2).

**Recommendations:**

5. Remove `flex` from the initial class list of the inner div (line 12) since `hidden` overrides it anyway. Add `flex` dynamically when the Stimulus controller shows the banner, or use the opacity-based approach from recommendation 2 which avoids this class conflict entirely. **[one-liner, low priority]**

---

## CSS Architecture: Adequate

**Observations:**

- The PwaInstallBanner does not use `ha-card`. This is correct -- it is a notification overlay, not a content card. Using `ha-card` would add the hover lift transform, which is wrong for a notification.

- The component does not use any project CSS custom properties (`var(--ha-*)`) for colors. Instead, it uses Tailwind's sky color palette directly (`text-sky-100`, `bg-sky-400/20`, etc.). FlashToasts does the same -- it uses `text-emerald-100`, `bg-emerald-400/20` directly rather than custom properties. This is consistent. The design tokens (`--ha-text`, `--ha-muted`, etc.) are for content areas and cards, while notification overlays use their own semantic color palettes.

- The gradient background uses an arbitrary value: `bg-[linear-gradient(140deg,...)]`. This is the same pattern as FlashToasts. If a third notification-style component appears with this gradient treatment, it would be worth extracting to a CSS utility class (e.g., `ha-toast-bg-sky`, `ha-toast-bg-emerald`). With two components, inline is acceptable.

- All Tailwind classes used by the component that are new to the codebase (listed below) will require a Docker rebuild (`bin/cli app rebuild`) to be compiled by Tailwind JIT. According to the Phase 7 Steps document, this rebuild was already performed during development and verified at runtime:
  - `bottom-6` (new -- `bottom-20` existed before, `bottom-6` did not)
  - `py-1.5` (new -- `py-1`, `py-2`, `py-3`, `py-8` existed before)
  - `bg-sky-400/20`, `bg-sky-500/20`, `border-sky-300/30`
  - `text-sky-100`, `text-sky-100/80`, `text-sky-200`
  - `hover:bg-sky-200/10`, `hover:bg-sky-500/30`, `hover:text-sky-100`

  Note: The committed `app/assets/builds/tailwind.css` does not contain these classes because the Docker container compiles CSS at runtime via Tailwind JIT. This is the same situation as FlashToasts (whose emerald overlay classes are also absent from the committed CSS). No action needed -- the rebuild handles this.

**No recommendations beyond noting the new Tailwind classes for rebuild awareness.**

---

## UI Component Library Sync: Missing

**Observations:**

- The `ui_library/` directory does NOT contain a `pwa_install_banner.yml` entry. Per the SKILL.md workflow: "After building a component, create a `.yml` entry here to keep the registry in sync." This entry is missing.

- The SKILL.md "Existing Project Components" table at the bottom of the file does NOT list PwaInstallBanner. It needs to be added.

- The `ui_library/index.html` was last regenerated before this component was created. After adding the YAML entry, the index must be regenerated with `mise x -- ruby ui_library/generate_index.rb`.

- Based on `generate_index.rb` line 37, the component would be categorized as "Feedback" because the filename matches the `banner` pattern. This is the correct category alongside `notice_banner` and `flash_toasts`.

**Recommendations:**

6. **(Required)** Create `ui_library/pwa_install_banner.yml` with the following content:

```yaml
component: Components::PwaInstallBanner
file: app/components/pwa_install_banner.rb
library_source: application_ui/overlays/notifications
library_variant: with_actions_below.html
description: Fixed-position PWA install prompt with download icon, title, description, install button, and dismiss. Uses sky-blue gradient matching FlashToasts pattern. Shown by Stimulus controller after 2+ page visits.
design_tokens: []
tailwind_classes:
  - fixed, bottom-6, right-6, z-50
  - rounded-2xl, border, p-4, gap-3, max-w-sm
  - text-sm, text-xs, font-semibold, font-medium
  - flex, items-start, items-center, justify-center
  - transition-all, duration-300, ease-out
  - bg-sky-400/20, bg-sky-500/20, text-sky-100, text-sky-200
```
**[required, one-liner]**

7. **(Required)** Add PwaInstallBanner to the SKILL.md "Existing Project Components" table. **[one-liner]**

8. **(Required)** Regenerate the browsable index: `mise x -- ruby ui_library/generate_index.rb`. **[one-liner]**

---

## Stimulus Controller Review: Strong

**Observations:**

- The controller properly uses `static targets = ["banner"]` and checks `this.hasBannerTarget` before DOM manipulation. This prevents errors if the target element is missing.

- Event listeners are added in `connect()` and removed in `disconnect()`. This is the correct Stimulus lifecycle pattern -- no memory leaks.

- Arrow functions (`capturePrompt = (event) => {...}`) are used for event handlers, ensuring correct `this` binding. This is a best practice for Stimulus event listeners added via `addEventListener`.

- The progressive disclosure logic (show after 2+ page visits, dismiss per session) is thoughtful UX. It avoids pestering first-time visitors while surfacing the install option to engaged users.

- `sessionStorage` is used for state (page visits, dismiss state). This means the banner can reappear in new sessions, which is the expected behavior for install prompts.

- Standalone mode detection (`window.matchMedia("(display-mode: standalone)")`) correctly suppresses the banner for users who have already installed the app.

**No recommendations -- the controller is clean and well-structured.**

---

## Offline Fallback Page: Adequate

**Observations:**

- `public/offline.html` is a standalone HTML file with inline styles. This is correct -- it must work without any server-rendered assets since it is served from the service worker cache.

- The page uses `background: #0b1220` which matches `--ha-panel` / `--ha-bg` (dark mode). This is appropriate -- the offline page should match the app's dark theme since `theme-color` is set to `#0b1220`.

- Font family falls back from "Space Grotesk" to system fonts. Since the page may be displayed when the network is unavailable, the Google Fonts import may fail. The fallback chain (`Segoe UI, system-ui, sans-serif`) matches the project's body font stack.

- The "Try again" button uses `background: #38bdf8` which is `--ha-accent`. Correct accent color usage.

- The page uses inline styles exclusively (no Tailwind classes). This is the right approach -- Tailwind CSS requires the compiled stylesheet, which may not be cached.

**No recommendations -- the offline page is correctly self-contained.**

---

## Summary of Recommendations

### Required (library sync)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 6 | Create `ui_library/pwa_install_banner.yml` entry | `ui_library/pwa_install_banner.yml` | one-liner |
| 7 | Add PwaInstallBanner to SKILL.md component table | `.claude/skills/ui-designer/SKILL.md` | one-liner |
| 8 | Regenerate `ui_library/index.html` | `ui_library/index.html` | one-liner |

### Medium Priority (polish)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 2 | Replace `hidden` toggle with opacity/transform animation | `pwa_install_banner.rb`, `pwa_controller.js` | moderate |
| 3 | Add exit animation before hiding the banner on dismiss | `pwa_controller.js` | moderate |

### Low Priority (nice-to-have)

| # | Issue | File | Effort |
|---|-------|------|--------|
| 1 | Add `aria_label: "Install Trip Journal"` to install button | `pwa_install_banner.rb:54` | one-liner |
| 5 | Remove `flex` from class list when `hidden` is present | `pwa_install_banner.rb:12` | one-liner |

---

## Overall Assessment

The PwaInstallBanner is **well-crafted and consistent** with the project's design system. It is clearly modeled after the FlashToasts component, and every structural decision -- gradient pattern, icon sizing, dismiss button, color palette, spacing, border radius -- faithfully replicates the FlashToasts template while substituting sky-blue for the emerald/rose color scheme. The Stimulus controller is clean with proper lifecycle management.

The two gaps are:

1. **Missing UI library registration** -- the component exists in code but is not tracked in `ui_library/` or listed in the SKILL.md component table. This is a bookkeeping omission that should be fixed before merging.

2. **No entrance/exit animation** -- the `hidden` class toggle causes instant show/hide, wasting the `transition-all duration-300 ease-out` declaration. An opacity + transform approach would produce a smooth entrance that matches the overall app's polished feel.

The component does not have any bugs, broken tokens, or convention violations. It is production-ready as-is, with the library sync items being the only required action.

Want me to apply these fixes?
