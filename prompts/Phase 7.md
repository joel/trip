# Phase 7: PWA + Mobile Capabilities

## Context

Phases 1-6 are complete. The application has full trip journaling, comments, reactions, checklists, exports, and comprehensive event-driven workflows. The codebase has 376 specs passing, zero Bullet alerts, and comprehensive seed data.

PWA scaffolding already exists: `manifest.json.erb` and `service-worker.js` are in `app/views/pwa/`, and PWA routes are already uncommented in `config/routes.rb`. However, the manifest has placeholder values and the service worker is a skeleton.

**Goal:** Make the app installable as a PWA on mobile and desktop, with proper branding, asset caching, responsive layout polish, and a Stimulus-driven install prompt.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### PWA Manifest & Icons
- **Update manifest.json.erb** with Trip Journal branding (name, short_name, description, theme_color, background_color matching `--ha-bg` and `--ha-accent`)
- **Generate app icons** — 192x192 and 512x512 PNG icons (use a simple "C" or compass icon matching the sidebar brand)
- **Add maskable icon** variant for Android adaptive icons
- **Add screenshots** for app store-style install dialog (desktop + mobile)

### Service Worker
- **Cache-first strategy for assets** — CSS, JS, fonts, images from Propshaft
- **Network-first for HTML** — Turbo navigation must not be intercepted
- **Offline fallback page** — simple "You're offline" page when network is unavailable
- **Cache versioning** — bump cache name on deploy to invalidate stale assets
- **Turbo compatibility** — ensure `fetch` event handler does not conflict with Turbo Drive or Turbo Streams

### Application Layout
- **Add `<link rel="manifest">` to application layout** (`app/views/layouts/application_layout.rb`)
- **Add mobile meta tags**: `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `theme-color`
- **Add apple-touch-icon** link for iOS home screen

### Install Prompt
- **Stimulus controller** `pwa_controller.js` — capture `beforeinstallprompt` event, show install banner, handle `appinstalled` event
- **Install banner component** — Phlex component for the install prompt UI, dismissible, shown once per session

### Responsive Layout Polish
- **Sidebar**: already collapses via `details/summary` — verify it works on 375px viewport
- **All pages**: verify all views render correctly at 375px (mobile), 768px (tablet), 1280px (desktop)
- **Touch targets**: verify all buttons meet minimum 44x44px touch target size
- **Image grid**: journal entry images should stack on mobile (1 column) vs 2-3 columns on desktop

---

## Files to Create (~8)

### Icons (3)
1. `public/icon-192.png` — 192x192 app icon
2. `public/icon-512.png` — 512x512 app icon
3. `public/icon-maskable.png` — maskable variant for Android

### Service Worker (1)
4. `app/views/pwa/service-worker.js` — replace skeleton with cache-first strategy (already exists, needs rewrite)

### Stimulus Controller (1)
5. `app/javascript/controllers/pwa_controller.js` — install prompt handler

### Component (1)
6. `app/components/pwa_install_banner.rb` — install prompt Phlex component

### Offline Page (1)
7. `public/offline.html` — simple offline fallback page

### Screenshot (1)
8. `public/screenshot-wide.png` — screenshot for install dialog

## Files to Modify (~3)

9. `app/views/pwa/manifest.json.erb` — update with proper branding
10. `app/views/layouts/application_layout.rb` — add manifest link, meta tags, install banner
11. `config/importmap.rb` — pin pwa_controller if needed

---

## Key Design Decisions

1. **Cache strategy**: Cache-first for static assets (CSS/JS/fonts/images served by Propshaft), network-first for HTML. This avoids conflicts with Turbo, which expects fresh HTML responses.

2. **No offline content caching**: V1 does not cache trip data for offline use. Only a fallback "You're offline" page is shown when the network is unavailable. Offline editing is explicitly out of scope per PRP.

3. **No push notifications in V1**: The PRP specifies "plan only" for push notifications. The service worker will be structured to allow adding push subscription later, but no VAPID keys or subscription management is implemented.

4. **Install prompt timing**: Show the install banner after the user has visited 2+ pages (engaged user), not immediately on first visit. Store dismiss state in `localStorage`.

5. **Icon generation**: Use a simple SVG-to-PNG approach. The sidebar already renders an "S" in a rounded square — generate a similar icon programmatically or use a static asset.

## Risks

1. **Turbo + Service Worker conflict** — `fetch` event handler must explicitly exclude Turbo Stream requests (`text/vnd.turbo-stream.html`) and Action Cable WebSocket connections from caching. Mitigate by checking `request.headers.get('Accept')` in the service worker.

2. **Cache invalidation on deploy** — stale cached assets after deploy could break the app. Mitigate with a versioned cache name (e.g., `catalyst-v1-{git-sha}`) and `activate` event cleanup.

3. **iOS PWA limitations** — iOS Safari has limited PWA support (no `beforeinstallprompt`, no push notifications). The install banner should detect iOS and show "Add to Home Screen" instructions instead.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Test Checklist
- [ ] Manifest loads at `/manifest` with correct metadata
- [ ] Service worker registers at `/service-worker`
- [ ] App is installable in Chrome (install prompt appears)
- [ ] Icons display correctly on home screen (Android, iOS)
- [ ] Static assets are cached by service worker (check DevTools > Application > Cache Storage)
- [ ] Turbo navigation still works after service worker registers
- [ ] Turbo Streams not intercepted by service worker
- [ ] Offline fallback page shown when network is disabled
- [ ] Install banner appears after 2+ page visits
- [ ] Install banner dismisses and doesn't reappear
- [ ] All pages render at 375px width without horizontal scroll
- [ ] Touch targets are >= 44px on mobile
- [ ] Sidebar collapses correctly on mobile

### Lighthouse Audit
- [ ] PWA score > 90 in Chrome Lighthouse
- [ ] Performance score > 80
- [ ] Accessibility score > 90

### Definition of Done
- [ ] App is installable on Chrome desktop and Android
- [ ] Manifest has correct branding, icons, and theme colors
- [ ] Service worker caches assets without breaking Turbo
- [ ] Offline fallback page works
- [ ] Install banner shown to engaged users
- [ ] All pages mobile-responsive at 375px
- [ ] No Bullet N+1 alerts on any page
- [ ] All existing tests still pass
- [ ] Runtime verification via agent-browser
