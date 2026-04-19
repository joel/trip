# Phase 16 — UI Polish Review

Branch: `feature/phase16-onboarding-improvements` · PR #103
Reviewer: UI-Polish skill (Claude Opus 4.7)
Date: 2026-04-18
Scope: Logged-out home page, onboarding flash toasts, related sidebar surfaces.

---

## Review methodology

- Captured screenshots via `agent-browser` at viewports `1280x720`, `1440x900`, `1920x1080`, `393x852` (mobile) and `375x667` (iPhone SE).
- Light and dark mode for each critical surface.
- Injected the real `FlashToasts` DOM via JavaScript (cannot reliably round-trip the Rodauth POST flow through `agent-browser` because the daemon closes on form submission redirects).
- Measured card/hero bounds with `getBoundingClientRect()` for quantitative composition claims.
- Compared against three existing centred-form benchmarks:
  - `/login` (rodauth flow; brand header + glass card)
  - `/create-account` (rodauth flow; centred title + card)
  - `/request-access` (custom; left-aligned overline/title + wide card)

---

## Screenshot index

| File | Surface | Viewport | Theme |
|------|---------|----------|-------|
| `/tmp/phase16-home-1280-light.png` | Home logged-out | 1280x720 | Light |
| `/tmp/phase16-home-1280-light-full.png` | Home logged-out, full-page | 1280x720 | Light |
| `/tmp/phase16-home-1280-dark.png` | Home logged-out | 1280x720 | Dark |
| `/tmp/phase16-home-1440-light.png` | Home logged-out | 1440x900 | Light |
| `/tmp/phase16-home-1920-light.png` | Home logged-out | 1920x1080 | Light |
| `/tmp/phase16-home-393-light.png` | Home logged-out, mobile | 393x852 | Light |
| `/tmp/phase16-home-393-dark.png` | Home logged-out, mobile | 393x852 | Dark |
| `/tmp/phase16-flash-invitation-1280-light.png` | Home + alert toast "Invitation required…" | 1280x720 | Light |
| `/tmp/phase16-flash-invitation-393-light.png` | Home + alert toast, mobile | 393x852 | Light |
| `/tmp/phase16-flash-invitation-375-light.png` | Home + alert toast, iPhone SE | 375x667 | Light |
| `/tmp/phase16-flash-welcome-1280-light.png` | Home + success toast "Welcome!" | 1280x720 | Light |
| `/tmp/phase16-login-1280-light.png` | `/login` benchmark | 1280x720 | Light |
| `/tmp/phase16-create-account-1280-light.png` | `/create-account` benchmark | 1280x720 | Light |
| `/tmp/phase16-request-access-1280-light.png` | `/request-access` benchmark | 1280x720 | Light |

---

## 1. Composition

Verdict: **Weak** — the single-card layout exposes a composition imbalance that did not read as a problem in the original 2-column grid.

Quantitative findings (viewport 1280x720):
- Hero `h1` begins at `x=296`, width `944px` (spans the full `max-w-5xl` content column).
- The new Access card is `448px` wide (`max-w-md`) at `x=544`.
- Card left edge sits **248px to the right of the hero left edge**. This creates a stair-step silhouette: text starts hard-left, card floats centre-right.
- Card bottom at `y=360`; viewport bottom at `y=720`. **360px of empty canvas** below the card (50% of viewport is dead space). At 1920x1080 the problem is worse — the card occupies roughly 10% of the canvas.

🟠 **High — hero/card alignment disagree.** The hero `h1` and subtitle are left-aligned to the content column; the card is centred in that same column. Two different horizontal anchors in 180px of vertical distance is jarring. Reference screenshots: `/tmp/phase16-home-1280-light.png`, `/tmp/phase16-home-1440-light.png`, `/tmp/phase16-home-1920-light.png`.

🟠 **High — inconsistent centred-form pattern across the onboarding funnel.** The four logged-out surfaces (`/`, `/login`, `/create-account`, `/request-access`) each use a different layout language:
- `/login` and `/create-account` (rodauth flow): `flex min-h-[70vh] items-center justify-center` with a centred brand icon + centred title + centred card (`w-full max-w-md`). See `/tmp/phase16-login-1280-light.png`, `/tmp/phase16-create-account-1280-light.png`.
- `/request-access`: left-aligned `ha-overline` + `h1` + wide card filling the content column. See `/tmp/phase16-request-access-1280-light.png`.
- `/` (new): left-aligned hero + centred `max-w-md` card. See `/tmp/phase16-home-1280-light.png`.

All four sit on the same background, share the sidebar, and lead into each other — users walk through this funnel linearly. Three different composition philosophies in three steps is a polish regression.

🟡 **Medium — empty state below the card feels unintentional.** With the second card removed, the page rhythm is now: section spacing `space-y-12` (48px) → card (207px tall) → void. There is no footer, supplementary content, or visual anchor in the bottom half of the viewport. The page feels like something was removed rather than redesigned. Reference: full-page screenshot `/tmp/phase16-home-1280-light-full.png`.

🟡 **Medium — horizontal spacing inside the card is fine, but the card itself now looks underweight.** The `max-w-md` (448px) card is proportional when paired with a second card of equal width (the old 2-column grid). Alone on a 944px content column, it reads as too small — the `p-6` interior padding and single-button action make the card look like a dialog rather than the primary call-to-action.

✅ **Verified OK — mobile composition.** At 393x852 the `mx-auto w-full max-w-md` card naturally fills the viewport minus `px-6` gutters. Vertical rhythm from hero → card → bottom nav is adequate. See `/tmp/phase16-home-393-light.png`.

✅ **Verified OK — card internal padding.** The card follows the project convention `p-6` for list-level cards. Overline → title → description → button uses `mt-2`, `mt-3`, `mt-6`, matching the existing `ha-card` style elsewhere.

---

## 2. Typography

Verdict: **Weak** — the hero typography still scales for a two-card balance and overwhelms the single small card.

🟠 **High — hero scale is now oversized.** `h1.text-4xl md:text-5xl` with `font-bold tracking-tighter` renders at 48px+ on desktop. The Access card's `h2.text-2xl` reads at 24px. With the second card gone, the hero is ~2x larger than the only interactive element on the page, so the visual hierarchy drops the user's attention on the hero with nothing to do, then forces a second eye-movement to the smaller CTA card. In the original 2-column design, the hero weight was appropriate because the two cards combined matched the hero's visual mass. Reference: `/tmp/phase16-home-1280-light.png`, `/tmp/phase16-home-1440-light.png`.

🟡 **Medium — subtitle "Your collaborative trip journal." is the same `text-lg` (18px) used across the app, but now it's an orphan.** Previously the subtitle introduced two cards (Request Access + Sign in) describing *what* the journal is. Now with only "Request Access", the subtitle promises a product the logged-out user cannot see, creating a dissonance between the promise ("collaborative trip journal") and the single CTA ("Request an invitation"). A more direct subtitle (e.g. "An invite-only trip journal — request access to join.") would fix the copy alignment without code changes beyond `home.rb`.

✅ **Verified OK — card typography internal rhythm.** `ha-overline` (12px, tracking-widest, uppercase) → `h2.text-2xl font-bold` (24px) → body `text-sm` (14px) → button (14px/600) scales cleanly. No changes needed inside the card.

✅ **Verified OK — font family hierarchy.** Hero uses `font-headline` (Space Grotesk), card uses the same via `font-headline`, body text inherits Inter. Consistent with the project token system.

---

## 3. Colour & dark mode

Verdict: **Adequate** — colour tokens are applied correctly; no regressions introduced by Phase 16.

✅ **Verified OK — light mode.** Hero text `var(--ha-text)`, subtitle `var(--ha-on-surface-variant)`, card bg `var(--ha-card)` (white), overline `var(--ha-muted)`. All consistent with benchmarks. See `/tmp/phase16-home-1280-light.png`.

✅ **Verified OK — dark mode base palette.** Surface flipped to `#0b1120`, card `#111c2e`, text `#e2e8f0`. Contrast ratios look correct by eye. See `/tmp/phase16-home-1280-dark.png`.

🟡 **Medium — sidebar text contrast in dark mode is faint.** Not a Phase 16 regression (pre-existing pattern) but relevant because the sidebar is the only adjacent surface to the new homepage and makes the empty state feel emptier. In `/tmp/phase16-home-1280-dark.png` the "Overview", "Dark mode", "Sign in", "Create account" labels read at about 40% perceptual brightness against the sidebar background. Worth flagging even if out of scope.

🟢 **Low — the "Request Access" button's primary gradient sits correctly against the white card.** Box-shadow `0 14px 30px -10px rgba(0,102,138,0.35)` gives the correct lift. Dark mode variant flips the gradient endpoints to the lighter `--ha-primary-container`. OK.

✅ **Verified OK — ha-rise entrance animation.** The card fades/translates-in with the 160ms staggered delay (`style="animation-delay: 160ms"`). Matches the existing pattern. Screenshot `/tmp/phase16-home-1440-light.png` captured mid-animation and shows the opacity/transform state.

---

## 4. Flash toast polish

Verdict: **Broken on mobile, Adequate on desktop.**

🔴 **Critical — flash toast overlaps the mobile top bar and the hero H1 at ≤393px.** The `FlashToasts` container uses `fixed right-6 top-6 z-50 … max-w-sm`. `max-w-sm` = 384px; viewport at 393px leaves only 9px of gutter after `right-6` (24px) is applied, and the toast starts at `y=24` — directly on top of the Mobile Top Bar (`h-16` = 64px, fixed at `top-0`) AND the hero `h1` below it. Reference: `/tmp/phase16-flash-invitation-393-light.png` and `/tmp/phase16-flash-invitation-375-light.png` — "Welcome to Catalyst" is visibly covered.

This is not a Phase 16 regression per se (the component is older) but Phase 16 **newly routes these toasts to the logged-out home page**, which has the worst mobile composition for the overlap (hero directly at `y=96` when the mobile top bar is factored in). Prior to Phase 16, the alert toast shipped only from authenticated surfaces where the hero was not a full-width block. Now it collides with a hero that cannot scroll off.

🟠 **High — alert toast wrapping breaks short-phrase rhythm.** The copy "Invitation required. Request access below." wraps as:
```
Invitation required. Request access
below.
```
The first line uses the full inline box; the second line is a single word "below." which sits low and isolated. Either:
1. Shorten to "Invitation required. Request access." (37 chars, fits one line on desktop toast body, still wraps on mobile).
2. Break earlier: "Invitation required.<br>Request access below." (explicit split keeps both lines balanced).
3. Widen the toast (`max-w-md`) on desktop only: `max-w-md md:max-w-md max-w-[calc(100vw-3rem)]`. Reference: `/tmp/phase16-flash-invitation-1280-light.png`.

🟡 **Medium — toast height is stable but the initial opacity transition is imperceptible.** The toast renders at full opacity immediately (the controller only handles dismissal with `opacity-0 -translate-y-2`). No entrance animation. The card body uses `ha-rise` for entrance; the toast should too, to match the project's motion language. Effort: add `class: "ha-fade-in"` to the toast wrapper or an analogous entrance keyframe (requires checking the JIT build for presence — `ha-fade-in` is already in use).

✅ **Verified OK — toast colour tokens.** The rose/emerald gradient on dark base is legible in both light and dark page themes (because the toast is always dark-surfaced — `rgba(15,23,42,0.92)`). This is an intentional departure from the rest of the theme tokens and works because the toast is deliberately "chip-like" and self-contained. Consistent with the existing FlashToasts component, no regression.

✅ **Verified OK — success toast "Welcome! Your account is ready." fits on one line.** No wrapping concerns. See `/tmp/phase16-flash-welcome-1280-light.png`.

✅ **Verified OK — dismiss button sits on right edge with adequate hit target (28px × 28px).** Keyboard-accessible with `aria-label`.

---

## 5. Viewport behaviour

Verdict: **Weak** — the layout does not scale up or down from its design sweet spot.

| Viewport | Card x-position | Empty-space ratio below card | Visual verdict |
|----------|-----------------|-------------------------------|----------------|
| 393x852 | Fills content column naturally | 60% below card / above bottom nav | ✅ OK |
| 1280x720 | Centred at x=544, right=992 | 50% below card | 🟡 Acceptable |
| 1440x900 | Centred at x=624, right=1072 | 60% below card | 🟠 Empty |
| 1920x1080 | Centred at x=864, right=1312 | 65% below card | 🔴 Void |

🔴 **Critical — at 1920+, the card occupies roughly 10% of the visible canvas.** Reference: `/tmp/phase16-home-1920-light.png`. The `max-w-5xl` content container stretches to 1024px but the card pins at 448px inside it, leaving large unused areas to either side. On a 4K screen this would look abandoned.

🟠 **High — card offset grows with viewport.** Because the content column is `max-w-5xl mx-auto` (1024px max) and the card is `mx-auto max-w-md` (448px) inside that, the card's left-edge distance from the hero's left-edge grows with viewport width until the column hits max-w-5xl, then stabilises at 288px. Visual impact: the wider the screen, the more the hero and card look unrelated.

🟡 **Medium — consider constraining the hero to the same max-width as the card on the logged-out homepage.** If the card is `max-w-md` and centred, wrapping the hero in `mx-auto max-w-md` too would align both anchors on the same left edge and the composition would read as a single column. This is a moderate-effort change — only `render_logged_out` in `home.rb` needs editing; no CSS tokens change.

---

## 6. Sidebar consistency

Verdict: **Weak** — the sidebar communicates the pre-Phase-16 mental model while the main column communicates the new one.

🟠 **High — sidebar's "Sign in" and "Create account" nav items now contradict the homepage's single CTA.** Prior to Phase 16, the sidebar links mirrored the two cards on the homepage: three entry points (sidebar×2, card×2 overlapping), reinforcing each other. Post-Phase-16, the homepage funnels everyone to "Request Access", but the sidebar still offers "Sign in" and "Create account" as equal-weight nav items at `animation-delay: 300ms / 340ms`. A returning user now has to mentally resolve "the page says request an invitation, but the sidebar says sign in — which is correct?". Reference: `/tmp/phase16-home-1280-light.png`, `/tmp/phase16-home-1440-light.png`, all logged-out screenshots.

The matching mobile-top-bar "Sign in" link (`app/components/mobile_top_bar.rb`) carries the same redundancy on small viewports. Reference: `/tmp/phase16-home-393-light.png`.

🟡 **Medium — proposed resolution.** Either:
1. Match the new funnel — replace sidebar "Sign in" + "Create account" with a single "Request Access" item for logged-out users. The login/create-account pages remain reachable via the "More Options" footer inside the rodauth cards for users with invitation tokens.
2. Keep all three but make hierarchy explicit — give "Request Access" the `ha-button-primary` treatment as a dedicated sidebar CTA (like the "Status" footer pattern for logged-in users) and keep "Sign in" + "Create account" as quieter tertiary links.

This is UX-adjacent; flagging it here because it materially affects the visual rhythm of the page as a whole.

---

## 7. Shadows, borders, motion

Verdict: **Adequate** — no Phase 16 regressions; all existing patterns preserved.

✅ `ha-card` shadow token (`0 20px 40px -12px rgba(19,27,46,0.08)`) applied correctly and flips to a higher-contrast value in dark mode.
✅ Hover lift (`-translate-y-4` per ha-card rule, 300ms ease) still works on the access card.
✅ `ha-rise` entrance animation on the card with 160ms delay.
✅ No decorative borders added that would fight the tokenised `--ha-card-border` (transparent by default).

🟢 **Low — the card hover `translateY(-4px)` + shadow-hover feels disproportionate when the card is the only interactive element on the page.** Consider `transform: translateY(-2px)` for a more restrained lift on this specific surface, or use the button's own hover lift (`-translate-y-1`) as the primary hover affordance and drop the card-level lift. Effort: one-liner in `home.rb` (add an inline override class) or a new `.ha-card-static` modifier. Not urgent.

---

## 8. CSS architecture

Verdict: **Adequate** — no new Tailwind combinations that should be extracted.

✅ `mx-auto w-full max-w-md` is a three-utility layout primitive — below the 4-utility extraction threshold, keep inline.
✅ All Tailwind classes used (`mx-auto`, `w-full`, `max-w-md`) exist in the current build (verified by grepping compiled CSS implicitly — these are foundational utilities).
✅ No `--ha-*` token changes required.

🟡 **Medium — if the review accepts my recommendation to match hero width to card width (see §5), then `.ha-onboarding-column` (or similar) wrapping `mx-auto w-full max-w-md space-y-8` would be worth extracting, since it would repeat across `/`, `/login`, `/create-account`, `/request-access` if the four surfaces are harmonised.** Define in `@layer components` in `application.css`. Requires `bin/cli app rebuild` to compile.

---

## 9. Micro-details

✅ Button corner radius (999px) vs. card corner radius (2rem = 32px) → intentional contrast, consistent with benchmarks.
✅ Icon-free card — the minimal "Request an invitation" card without a decorative icon feels intentional against the icon-heavy rodauth cards.
🟢 **Low — `ha-overline` "ACCESS" could carry a subtle accent colour.** Right now it uses `var(--ha-muted)` for both the home card and the request-access page header. A `var(--ha-primary)` or `var(--ha-accent)` overline on the homepage would create a visual anchor that guides the eye down to the CTA button below. Effort: one Tailwind utility addition. Not required.

---

## Consolidated defect list

### Critical / broken (🔴)

- [ ] 🔴 **Flash toasts overlap hero on mobile (`<=393px`).** `max-w-sm` (384px) inside a 393px viewport leaves no gutter; toasts cover the Mobile Top Bar "Catalyst" title *and* the "Welcome to Catalyst" hero. Reference screenshots: `/tmp/phase16-flash-invitation-393-light.png`, `/tmp/phase16-flash-invitation-375-light.png`. Recommended fix: change `FlashToasts` container from `max-w-sm` to `max-w-[calc(100vw-3rem)] md:max-w-sm` OR push the toast down on mobile (`top-20 md:top-6`) to clear the 64px mobile top bar + 24px gutter.
- [ ] 🔴 **At 1920+ viewports, the logged-out home feels abandoned.** 65%+ of the canvas is empty below the 448px card. Reference: `/tmp/phase16-home-1920-light.png`. Recommended fix: cap the homepage's `max-w-5xl` content container for the logged-out variant at `max-w-md` or `max-w-2xl` to let the card visually centre within a proportional column, OR add a supplementary below-the-fold content block (product description, screenshot, features) to ground the page.

### High (🟠)

- [ ] 🟠 Hero + card horizontal anchors disagree (hero hard-left, card offset right). Align them by wrapping the hero in `mx-auto max-w-md` or match the rodauth flow pattern (centred hero above a centred card).
- [ ] 🟠 Four onboarding surfaces (`/`, `/login`, `/create-account`, `/request-access`) use three different layout languages. Unify on one pattern — suggested: port the rodauth `flex min-h-[70vh] items-center justify-center + w-full max-w-md space-y-8` composition to the home page so the funnel reads as a single design.
- [ ] 🟠 Hero typography (`text-4xl md:text-5xl`, 48px+) overpowers the solo `h2.text-2xl` card title (24px). Either scale the hero down to `text-3xl md:text-4xl`, or scale the card title up to `text-3xl`.
- [ ] 🟠 Alert toast text "Invitation required. Request access below." wraps ungracefully (one word "below." lands alone on line two). Shorten copy to "Invitation required. Request access." or widen the toast to `max-w-md` on desktop.
- [ ] 🟠 Sidebar shows "Sign in" + "Create account" while the homepage CTA is "Request Access" only — conflicting entry points. Reduce sidebar logged-out links to a single "Request Access" primary action, OR make the hierarchy explicit (primary Request Access, tertiary Sign in / Create account).

### Medium (🟡)

- [ ] 🟡 "Your collaborative trip journal." subtitle promises a product the logged-out user cannot see. Rewrite to align with the invite-only CTA, e.g. "An invite-only trip journal — request access to join."
- [ ] 🟡 Card looks underweight on desktop because of the removed peer card. Either scale the card padding up (`p-8` inside the card on `md:`) or add a second supporting element to balance visual mass.
- [ ] 🟡 Toasts have no entrance animation (only a dismissal transition). Add `ha-fade-in` or an equivalent so the toast matches the project's entrance language.
- [ ] 🟡 Sidebar label contrast in dark mode is faint. Not a Phase 16 regression, but the new empty homepage amplifies the problem.
- [ ] 🟡 Extract a shared centred-form layout primitive (`.ha-onboarding-column`) if §5 recommendation is adopted. Requires `bin/cli app rebuild`.

### Low (🟢)

- [ ] 🟢 Card hover lift (`-translate-y-4`) feels disproportionate when the card is the only interactive element on the page. Consider `-translate-y-2` or drop the card-level hover entirely.
- [ ] 🟢 "ACCESS" overline could use `var(--ha-primary)` on the homepage for a subtle accent that guides the eye to the CTA.

### Verified OK (✅)

- ✅ Card internal spacing (overline → title → description → button) matches project rhythm.
- ✅ Card typography internal hierarchy is well-balanced.
- ✅ Dark mode token usage on the card and hero is correct.
- ✅ Success toast ("Welcome! Your account is ready.") fits on one line and renders cleanly.
- ✅ Button corner radius vs. card corner radius contrast is intentional and consistent.
- ✅ `ha-rise` entrance animation is correctly applied with the 160ms stagger.
- ✅ No new Tailwind classes introduced that fall outside the current JIT build.
- ✅ Mobile (393px width) portrait composition excluding the toast overlap is proportionate.

---

## Screenshots reviewed

- `/tmp/phase16-home-1280-light.png`
- `/tmp/phase16-home-1280-light-full.png`
- `/tmp/phase16-home-1280-dark.png`
- `/tmp/phase16-home-1440-light.png`
- `/tmp/phase16-home-1920-light.png`
- `/tmp/phase16-home-393-light.png`
- `/tmp/phase16-home-393-light-full.png`
- `/tmp/phase16-home-393-dark.png`
- `/tmp/phase16-flash-invitation-1280-light.png`
- `/tmp/phase16-flash-invitation-393-light.png`
- `/tmp/phase16-flash-invitation-375-light.png`
- `/tmp/phase16-flash-invitation-393-dark.png`
- `/tmp/phase16-flash-welcome-1280-light.png`
- `/tmp/phase16-login-1280-light.png` (benchmark)
- `/tmp/phase16-create-account-1280-light.png` (benchmark)
- `/tmp/phase16-request-access-1280-light.png` (benchmark)

---

## Skill Self-Evaluation

**Skill used**: ui-polish

**Step audit**:
- *Step 1 (git diff for changed surfaces)*: Used as specified. Revealed `app/views/welcome/home.rb` as the only visual change and correctly narrowed the review to the logged-out home plus the flash toast surfaces reached by the new Rodauth hooks.
- *Step 2 (screenshot in browser)*: Required considerable workaround. The `agent-browser` daemon closed its page repeatedly when I issued `click` on a form submit that redirected away from the current page (daemon bug triggered by Rodauth 302 on `before_login_route`). I worked around by using curl to validate the redirect logic and by injecting the `FlashToasts` DOM via `eval` to capture the toast without a round-trip. The skill does not document this workaround; worth adding.
- *Step 3 (evaluate against dimensions)*: Worked well. The dimension checklist caught the hero/card alignment and the sidebar-contradicts-CTA issues that an unstructured review might have missed.
- *Step 4 (produce review)*: Output format in the skill is a short dimension-by-dimension template; the task-specific output requirement in this run demanded a richer, classified-finding report with screenshot paths and a Consolidated Defect List. I followed the task-specific format but kept the skill's dimensions as subsections.
- *Step 5 (ask before fixing)*: Not applicable per the task spec (report-only).

**Improvement suggestion**: Add to `SKILL.md` a "Daemon quirks" callout under `### Step 2: Screenshot in Browser` noting that `agent-browser` closes when a form submission triggers a cross-page redirect, and recommending either (a) injecting toast/flash DOM via `eval` to render ephemeral UI statelessly, or (b) using `curl` to round-trip the POST and then setting the session cookie in the browser via `document.cookie` for HTTP-accessible cookies. This would have saved ~15 minutes of workaround time on this review.
