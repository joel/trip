# QA Review -- feature/phase-7-pwa-mobile

**Branch:** `feature/phase-7-pwa-mobile`
**Phase:** 7
**Date:** 2026-03-24
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Unit/integration tests:** 376 examples, 0 failures, 2 pending
- **System tests:** 13 examples, 0 failures
- **RuboCop lint:** 338 files, no offenses
- **ERB lint:** 15 files, no errors
- **Importmap warning:** `Importmap skipped missing path: controllers/pwa_controller.js` appears 3 times during system tests (see E3)

---

## Acceptance Criteria

- [x] Manifest loads at `/manifest.json` with correct metadata -- PASS (correct JSON, branding, icons, screenshot, categories)
- [ ] Service worker registers at `/service-worker` -- FAIL: D1 (no registration code exists)
- [ ] App is installable in Chrome (install prompt appears) -- FAIL: depends on D1 (service worker must be registered for `beforeinstallprompt` to fire)
- [x] Icons display correctly -- PASS (192px, 512px, maskable all render as compass icons with correct dimensions)
- [ ] Static assets are cached by service worker -- FAIL: depends on D1
- [ ] Turbo navigation still works after service worker registers -- CANNOT TEST: depends on D1
- [ ] Turbo Streams not intercepted by service worker -- CANNOT TEST: depends on D1 (code logic is correct per review)
- [ ] Offline fallback page shown when network is disabled -- FAIL: depends on D1
- [ ] Install banner appears after 2+ page visits -- FAIL: depends on D1 (no `beforeinstallprompt` event fires without registered service worker)
- [ ] Install banner dismisses and doesn't reappear -- PARTIAL: dismiss uses `sessionStorage`, so it resets on new tab/session (see E1)
- [ ] All pages render at 375px width without horizontal scroll -- NOT IMPLEMENTED (see E2)
- [ ] Touch targets are >= 44px on mobile -- NOT TESTED (see E2)
- [ ] Sidebar collapses correctly on mobile -- NOT TESTED (see E2)
- [x] Offline page renders correctly when accessed directly -- PASS (dark theme, centered layout, "You're offline" heading, "Try again" button)
- [x] Meta tags present in `<head>` -- PASS (`theme-color`, `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `application-name`, `mobile-web-app-capable`, `manifest`, `apple-touch-icon`)
- [x] PWA Stimulus controller element present in DOM -- PASS (`data-controller="pwa"` rendered in body)
- [x] Manifest content type is correct -- PASS (`application/json; charset=utf-8`)
- [x] Service worker content type is correct -- PASS (`text/javascript; charset=utf-8`)
- [x] All icon assets return HTTP 200 -- PASS (icon-192.png, icon-512.png, icon-maskable.png, icon.png, icon.svg, screenshot-wide.png)
- [x] No Bullet N+1 alerts -- PASS (no warnings in Docker logs)
- [x] All existing tests still pass -- PASS

---

## Defects (must fix before merge)

### D1: Service worker is never registered -- entire PWA caching and install flow is non-functional

**Severity:** Critical (blocks core feature)

**Evidence:**
- `navigator.serviceWorker.getRegistrations()` returns `[]` in the browser
- No `navigator.serviceWorker.register()` call exists anywhere in the codebase
- Searched all `.js`, `.rb`, `.erb`, and `.html` files -- the only reference to "service-worker" is the route definition in `config/routes.rb`

**Expected:** The application should register the service worker on page load so that:
1. Static assets are cached via the cache-first strategy
2. The offline fallback page is precached and served when the network is unavailable
3. The `beforeinstallprompt` event can fire (requires a registered service worker with a fetch handler)
4. The PWA install banner can function

**Actual:** The service worker file is served at `/service-worker.js` but no JavaScript in the application calls `navigator.serviceWorker.register("/service-worker.js")`. The browser never installs the service worker, so:
- No assets are cached
- The offline fallback never triggers
- The `beforeinstallprompt` event never fires
- The install banner can never appear (by design, since it waits for `beforeinstallprompt`)

**Impact:** This defect renders the entire service worker implementation inert. The service worker code is correct in isolation, but it has zero runtime effect.

**Recommended fix:** Add service worker registration to the application entry point. Either:

**Option A** -- Add to `app/javascript/application.js`:
```javascript
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
}
```

**Option B** -- Add to the Stimulus `pwa_controller.js` `connect()` method:
```javascript
connect() {
  this.deferredPrompt = null

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
  }

  window.addEventListener("beforeinstallprompt", this.capturePrompt)
  window.addEventListener("appinstalled", this.handleInstalled)

  if (this.shouldShowBanner()) {
    this.incrementPageVisits()
  }
}
```

Option A is preferable because service worker registration should happen early and independently of the install banner component.

---

## Edge Case Gaps (should fix or document)

### E1: Banner dismiss state uses `sessionStorage` instead of `localStorage`

**File:** `app/javascript/controllers/pwa_controller.js:48`

The Phase 7 plan (item 4) specifies: "Store dismiss state in `localStorage`". The implementation uses `sessionStorage` for both the dismiss flag and the page visit counter.

**Risk if left unfixed:** Users who dismiss the install banner will see it again every time they open a new tab or close and reopen the browser. This is annoying and contradicts the plan. The page visit counter also resets per session, meaning the "2+ page visits" engagement heuristic measures visits within a single session rather than across sessions.

**Recommendation:** Change `sessionStorage` to `localStorage` for the dismiss flag (`pwa-banner-dismissed`). The page visit counter can remain in `sessionStorage` if the intent is to measure session engagement, but this should be a documented decision. If the intent is cumulative engagement tracking, switch it to `localStorage` as well.

### E2: Responsive Layout Polish scope items were not implemented

**Risk if left unfixed:** The Phase 7 plan explicitly includes:
- Verify all views render correctly at 375px (mobile), 768px (tablet), 1280px (desktop)
- Verify all buttons meet minimum 44x44px touch target size
- Verify journal entry images stack on mobile (1 column) vs 2-3 columns on desktop

None of these verification or implementation tasks appear in the diff. The only mobile-related changes are meta tags. If this scope was intentionally deferred, it should be documented. If it was forgotten, it should be completed before merge.

**Recommendation:** Either complete the responsive layout verification and fixes, or explicitly defer to a separate PR/issue with documentation in the Phase 7 steps.

### E3: Importmap warning for `pwa_controller.js` during test execution

**Evidence:** During system tests, the following warning appears 3 times:
```
Importmap skipped missing path: controllers/pwa_controller.js
```

**Risk if left unfixed:** This suggests the importmap cannot resolve the pwa_controller in the test environment. While the controller file exists at the expected path and tests pass, this warning could indicate a path resolution issue in CI or production environments. The controller may silently fail to load.

**Recommendation:** Investigate whether this warning appears in production or only in test. Verify the controller actually initializes by checking `Stimulus.debug = true` in a development browser console.

### E4: Static cache version is hardcoded -- stale assets after deploy

**File:** `app/views/pwa/service-worker.js:1`

`CACHE_VERSION` is hardcoded to `"catalyst-v1"`. The security review (W2, W3) flagged this: after a deploy, the activate handler will not purge old cached assets because the cache name stays the same. Users will see stale CSS/JS until they hard-refresh.

**Risk if left unfixed:** Broken pages after deploy if HTML references new asset fingerprints but the service worker serves old cached versions.

**Recommendation:** Use ERB to embed a deploy identifier:
```javascript
const CACHE_VERSION = "catalyst-<%= ENV.fetch('GIT_SHA', 'v1') %>"
```

### E5: No `"narrow"` form_factor screenshot in manifest

**File:** `app/views/pwa/manifest.json.erb:29-36`

The manifest includes a `"wide"` screenshot (1280x720) but no `"narrow"` (mobile) screenshot. Chrome on Android uses `"narrow"` screenshots in the "richer install UI". Without a narrow screenshot, the install dialog on mobile will be less visually appealing.

**Risk if left unfixed:** Suboptimal install experience on mobile devices.

**Recommendation:** Generate a `screenshot-narrow.png` (e.g., 750x1334) showing the mobile view and add it to the manifest.

### E6: No iOS-specific install guidance

**File:** `app/javascript/controllers/pwa_controller.js`

The Phase 7 plan (Risks, item 3) states: "iOS Safari has limited PWA support (no `beforeinstallprompt`, no push notifications). The install banner should detect iOS and show 'Add to Home Screen' instructions instead."

The current implementation only shows the install banner when `beforeinstallprompt` fires, which never happens on iOS Safari. iOS users will never see any install guidance.

**Risk if left unfixed:** The PWA install feature is invisible to all iOS users.

**Recommendation:** Detect iOS Safari and show alternative instructions (e.g., "Tap the Share button, then 'Add to Home Screen'").

---

## Observations

- The Phlex component `PwaInstallBanner` applies both `hidden` and `flex` Tailwind classes to the banner `div`. In the compiled Tailwind CSS for this project, `.hidden` appears after `.flex` in the `@layer utilities` block, so `display: none` correctly wins. However, this pattern is fragile -- if Tailwind's JIT output ordering changes (e.g., after a rebuild that scans classes in a different order), `flex` could override `hidden`. A safer approach would be to use `hidden` alone and add `flex` only when showing the banner (i.e., `classList.replace("hidden", "flex")` instead of `classList.remove("hidden")`).
- The service worker file at `app/views/pwa/service-worker.js` has the `.js` extension but is served through Rails' `PwaController` as an ERB template. Despite this, no ERB tags are used. This is correct for now but means the ERB rendering pipeline runs for no benefit.
- The `offline.html` page references the `Space Grotesk` font family but does not load it via a `<link>` or `@font-face`. The font will fall back to `-apple-system, BlinkMacSystemFont, sans-serif`. This is actually fine for an offline page (no network to fetch the font), but the `font-family` declaration is misleading.
- The service worker's `isStaticAsset()` regex does not match fingerprinted Propshaft assets that use query strings (e.g., `/assets/application-8b441ae0.css`). The regex `\.(css|js|...)(\?|$)` would match, but Propshaft uses filename-based fingerprinting (hash in the filename, no query string), so this is not an issue in practice.
- The `icon-maskable.png` is 512x512 but the manifest declares its `sizes` as `"512x512"`. For maskable icons, the visible "safe zone" is the inner 80% circle. The actual icon content in `icon-maskable.png` is scaled to approximately 72% of the canvas, which is within the safe zone. This is correct.

---

## Regression Check

- **Trip CRUD** -- PASS: Trips index and show pages render correctly for seeded trips
- **Journal entries** -- PASS: No changes to entry views; seeded entries render
- **Authentication** -- PASS: Login page renders, email auth flow works (tested via curl; email delivery depends on MailCatcher timing)
- **Comments & reactions** -- PASS: No changes to comment/reaction views; seeded data renders
- **Checklists** -- PASS: No changes to checklist views
- **Members** -- PASS: No changes to member views
- **Sidebar navigation** -- PASS: Sidebar renders correctly with all navigation items
- **Dark mode toggle** -- PASS: Theme controller present and functional
- **Meta tags in `<head>`** -- PASS: All PWA meta tags verified via curl and browser eval

---

## Summary

The Phase 7 implementation has one critical defect (D1) that must be fixed before merge: **the service worker is never registered**, which means the entire caching, offline fallback, and install prompt functionality is non-functional. The service worker code itself is well-structured, but without a `navigator.serviceWorker.register()` call, it has zero runtime effect.

There are six edge case gaps (E1-E6) that should be addressed or consciously deferred:
- E1: `sessionStorage` vs `localStorage` for banner dismiss
- E2: Responsive layout polish was not implemented (scope item skipped)
- E3: Importmap warning in tests
- E4: Static cache version (security review already flagged)
- E5: Missing narrow screenshot for mobile install UI
- E6: No iOS install guidance (plan risk item not addressed)

No regressions were found. All existing tests pass. The security review's warnings (W1-W4) remain valid and should be tracked.
