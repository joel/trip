# UX Review -- feature/phase-7-pwa-mobile

**Branch:** `feature/phase-7-pwa-mobile`
**Phase:** 7 -- PWA + Mobile Capabilities
**Date:** 2026-03-24
**Reviewer:** Claude (UX review pass)
**Source of truth:** Live screenshots from `agent-browser` at `https://catalyst.workeverywhere.docker/`

---

## Broken (blocks usability)

### B1: Service worker is never registered -- install banner and offline fallback are non-functional

**Surfaces affected:** All pages (PWA install banner), offline fallback page

There is no `navigator.serviceWorker.register()` call anywhere in the codebase. Without service worker registration:
- The `beforeinstallprompt` event never fires, so the `PwaInstallBanner` component will never become visible to any user on any platform.
- The offline fallback page (`/offline.html`) is precached by the service worker, but since the SW is never installed, users who go offline will see the browser's default offline error instead of the custom offline page.
- Static asset caching never activates.

The install banner, service worker, and offline page are all correctly implemented in isolation, but the glue that connects them (SW registration) is missing. Users experience zero PWA functionality.

**Recommended fix:** Add service worker registration to `app/javascript/application.js`:
```javascript
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
}
```

### B2: Sidebar does not collapse on mobile -- main content is inaccessible at 375px

**Surfaces affected:** All pages at viewport widths below ~600px

At 375px (standard mobile width), the sidebar occupies approximately 240px of the 375px viewport. The remaining 135px shows a sliver of main content that is cut off and unreadable. The text "Welcome home" appears as "Wel hom" with the rest clipped. Navigation links, cards, and action buttons in the main content area are partially or fully hidden behind the sidebar.

The sidebar uses a `<details open>` element for its collapse toggle, but it starts `open: true` at all viewports with no responsive breakpoint logic to collapse it on mobile. There is no hamburger menu or swipe-to-dismiss interaction.

This is a pre-existing issue (not introduced by Phase 7), but Phase 7 is specifically about mobile capabilities, and shipping a PWA that is unusable on mobile devices contradicts the phase's purpose. A user who installs the app on their phone via the install prompt would land on a broken layout.

**Recommended fix:** Add responsive sidebar behavior:
- At `md:` breakpoint and above: sidebar is visible (current behavior).
- Below `md:`: sidebar is hidden by default, triggered by a hamburger menu button in a top bar.
- Alternatively, start `<details>` with `open: false` below `md:` and add a visible toggle button.

---

## Friction (degrades experience)

### F1: Install banner dismiss button is too small for touch interaction (28x28px)

**File:** `app/components/pwa_install_banner.rb:64-72`

The dismiss button uses `h-7 w-7` (28x28px), which is below the WCAG 2.5.8 Target Size (Minimum) of 44x44px. On a mobile device, users may have difficulty tapping the dismiss button, especially with larger fingers or in motion.

**Recommended fix:** Increase the dismiss button to `h-11 w-11` (44x44px), or add invisible padding that extends the tap target while keeping the visual size compact:
```ruby
button(
  type: "button",
  data: { action: "pwa#dismiss" },
  class: "relative flex h-11 w-11 items-center justify-center rounded-full " \
         "text-sky-100/80 transition hover:bg-sky-200/10 hover:text-sky-100",
  aria_label: "Dismiss"
)
```

### F2: Install button is too small for touch interaction (~27px tall)

**File:** `app/components/pwa_install_banner.rb:54-59`

The Install button uses `px-3 py-1.5 text-xs`, which produces a button approximately 27px tall. This is well below the 44px minimum touch target for mobile devices.

**Recommended fix:** Increase padding to `px-4 py-2.5 text-sm` to bring the button height closer to 44px.

### F3: Offline page "Try again" button is 38px tall -- below 44px minimum

**File:** `public/offline.html:40-51`

The "Try again" button measures 38px in computed height. While close to the 44px minimum, it falls short. Additionally, the button has no `:focus` or `:focus-visible` styles, making it invisible to keyboard users.

**Recommended fix:** Increase padding to `0.75rem 1.5rem` (12px 24px) and add a focus style:
```css
button:focus-visible {
  outline: 2px solid #38bdf8;
  outline-offset: 2px;
}
```

### F4: Banner dismiss uses sessionStorage -- banner reappears on every new tab

**File:** `app/javascript/controllers/pwa_controller.js:47-48`

When a user dismisses the install banner, the dismiss state is stored in `sessionStorage`. This means the banner will reappear every time the user opens a new tab, closes and reopens the browser, or navigates from an external link. This creates a repetitive dismissal chore.

The Phase 7 plan specified `localStorage` for the dismiss state.

**Recommended fix:** Change `sessionStorage` to `localStorage` for the `pwa-banner-dismissed` key:
```javascript
dismiss() {
  this.hideBanner()
  localStorage.setItem("pwa-banner-dismissed", "true")
}

isDismissed() {
  return localStorage.getItem("pwa-banner-dismissed") === "true"
}
```

### F5: Offline page icon is semantically confusing

**File:** `public/offline.html:56-59`

The SVG icon on the offline page is an "X" mark (two crossed diagonal lines inside a circle). This symbol typically communicates "close", "error", or "delete" -- not "offline" or "no connection". Users may momentarily interpret this as an error dialog rather than an offline state notification.

**Recommended fix:** Replace with a WiFi-off icon or a cloud with a slash through it, which more clearly communicates "no internet connection."

### F6: Offline page is always dark -- ignores user's theme preference

**File:** `public/offline.html:9-17`

The offline page uses hardcoded dark colors (`background: #0b1220; color: #e2e8f0`). If a user has the app in light mode and goes offline, they will see a jarring transition to a dark page. Since the offline page is static HTML (no access to the app's theme system), it cannot match the app's current theme.

**Recommended fix:** Add a `prefers-color-scheme` media query to provide a light variant:
```css
@media (prefers-color-scheme: light) {
  body { background: #f8fafc; color: #1e293b; }
  p { color: #64748b; }
  button {
    background: rgba(56, 189, 248, 0.1);
    border-color: rgba(56, 189, 248, 0.3);
  }
}
```

### F7: No iOS install guidance -- PWA install is invisible to all iOS users

**File:** `app/javascript/controllers/pwa_controller.js`

iOS Safari does not fire `beforeinstallprompt`. The install banner logic entirely depends on this event. iOS users -- a significant portion of mobile users -- will never see any indication that the app can be installed.

**Recommended fix:** Detect iOS Safari in the controller and show alternative instructions (e.g., "Tap Share, then 'Add to Home Screen'") instead of the install button. The banner content can be swapped based on platform detection.

---

## Suggestions (nice to have)

### S1: Add a narrow screenshot to manifest for richer mobile install UI

The manifest includes a `"wide"` screenshot (1280x720) but no `"narrow"` form factor screenshot. Chrome on Android uses narrow screenshots in the install dialog. Adding a mobile screenshot (e.g., 750x1334) would make the install experience more polished.

### S2: Cache version is hardcoded to "catalyst-v1"

`CACHE_VERSION` in `service-worker.js` is static. After deploys, users may see stale cached assets until they hard-refresh. Consider embedding a deploy identifier (e.g., `ENV['GIT_SHA']`) via ERB.

### S3: Space Grotesk font reference in offline page will never load

The offline page references `'Space Grotesk'` in its `font-family` stack, but the font is never loaded (no `<link>` or `@font-face`). The fallback system fonts will always be used. Removing the reference avoids confusion about whether the font matters.

### S4: Install banner uses dark-only color scheme

The `PwaInstallBanner` component uses hardcoded dark colors (`bg-[linear-gradient(...rgba(15,23,42,0.92))]`, `text-sky-100`). In light mode, this creates a dark floating card over a light background. While this provides contrast and may be intentional as a design choice, it looks disconnected from the light theme. Consider adapting the banner to use CSS variables from the design system.

### S5: hidden + flex class pattern is fragile

The banner `div` applies both `hidden` and `flex` Tailwind classes simultaneously. While Tailwind currently orders `hidden` after `flex` in the utility layer (making `display: none` win), this ordering is an implementation detail. A more robust pattern would be to use `classList.replace("hidden", "flex")` in `showBanner()` and `classList.replace("flex", "hidden")` in `hideBanner()`.

---

## Flow Coherence Assessment

### Install Prompt Flow
1. User visits the app (page 1) -- banner hidden, page visits counter increments.
2. User navigates to another page (page 2) -- counter reaches 2.
3. If `beforeinstallprompt` has fired: banner appears with "Install Trip Journal" message.
4. User taps "Install" -- browser's native install dialog appears.
5. User confirms install -- `appinstalled` event fires, banner hides.
6. Alternatively, user taps dismiss (X) -- banner hides, `sessionStorage` flag set.

**Verdict:** The flow logic is correct. The 2-visit engagement threshold avoids annoying first-time visitors. The dismiss mechanism prevents immediate re-pestering. However, the flow is currently non-functional due to B1 (no SW registration). Once B1 is fixed, the flow will work on Chromium browsers but not on iOS (see F7).

### Offline Flow
1. User visits the app while online -- service worker installs and precaches `/offline.html`.
2. User loses connectivity -- next navigation request fails.
3. Service worker catches the failed fetch and returns the cached `/offline.html`.
4. User sees "You're offline" page with a "Try again" button.
5. User regains connectivity and taps "Try again" -- page reloads normally.

**Verdict:** The flow design is sound. The offline page is clear and actionable. However, the flow is non-functional due to B1. The offline page icon could better communicate "no connection" (see F5).

---

## Accessibility Summary

| Check | Status | Notes |
|-------|--------|-------|
| Keyboard reachability | PASS | Install and dismiss buttons are standard `<button>` elements |
| aria-label on dismiss | PASS | `aria_label: "Dismiss"` present |
| aria-hidden on decorative icon | PASS | SVG icon in banner has `aria_hidden: "true"` |
| Color contrast (dark mode) | PASS | Sky-100 text on dark gradient background exceeds 4.5:1 |
| Color contrast (light mode) | MARGINAL | Sky-100 text on dark banner is visible, but the dark banner on light page may cause confusion |
| Touch targets | FAIL | Dismiss (28px), Install (~27px), Try again (38px) all below 44px minimum |
| Focus indicators | MISSING | Offline page button has no focus styles |
| Page `lang` attribute | PASS | Offline page has `lang="en"` |
| Viewport meta | PASS | Both app and offline page have `width=device-width,initial-scale=1` |

---

## Screenshots Reviewed

| Page | Viewport | Mode | Key Finding |
|------|----------|------|-------------|
| Home (logged out) | 1280px | Light | Clean layout, sidebar and content render correctly |
| Home (logged out) | 375px | Light | **Sidebar blocks main content** -- text clipped to "Wel hom" |
| Home (logged out) | 768px | Light | Sidebar visible, main content readable but cramped |
| Home (logged in) | 1280px | Light | Clean layout with Users/Security cards, nav items visible |
| Home (logged in) | 1280px | Dark | Dark mode works well, good contrast |
| Trips index | 1280px | Dark | Trip cards render correctly in grid |
| Login page | 1280px | Light | Email input + Login button, clear form |
| Email auth confirm | 1280px | Light | "Finish signing in" with Login button, clean |
| Auth options | 1280px | Light | WebAuthn and email auth options, clear choices |
| Offline page | 1280px | Dark | Centered layout, "You're offline" heading, Try again button |
| Offline page | 375px | Dark | Responsive, content wraps and remains readable |
| Manifest.json | 1280px | -- | Correct JSON with Trip Journal branding, icons, screenshot |
| PWA icons | -- | -- | Compass design, consistent across 192px, 512px, maskable, SVG |
| PWA install banner | 1280px | Light | Banner visible in bottom-right, dark floating card style |
