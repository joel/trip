# Phase 7: PWA + Mobile Capabilities - Steps Taken

**Date:** 2026-03-24
**Issue:** [#33](https://github.com/joel/trip/issues/33)
**PR:** [#34](https://github.com/joel/trip/pull/34)
**Branch:** `feature/phase-7-pwa-mobile`

---

## Step 1: GitHub Issue & Kanban

- Created GitHub issue #33 with full scope and verification plan
- Note: Kanban board update requires `read:project` scope refresh (interactive login needed)

## Step 2: Feature Branch

- Created `feature/phase-7-pwa-mobile` from `main`
- Explored existing PWA scaffolding:
  - `manifest.json.erb` — placeholder values, single `icon.png` reference
  - `service-worker.js` — skeleton with commented-out push notification code
  - `application_layout.rb` — already had manifest link, apple-mobile-web-app-capable, apple-touch-icon
  - `config/routes.rb` — PWA routes already uncommented (`/manifest`, `/service-worker`)
  - `config/importmap.rb` — uses `pin_all_from` for controllers (auto-discovers new ones)
  - `public/icon.svg` — red circle placeholder, `public/icon.png` — 512x512 red circle

## Step 3: PWA Manifest & Icons

### Icons Generated
- Created new `public/icon.svg` — compass-style icon with:
  - Dark gradient background (#0b1220 to #111827) matching `--ha-panel`
  - Blue north needle (#38bdf8) matching `--ha-accent`
  - Green south needle (#34d399) matching `--ha-accent-2`
  - Gray east/west needles (#94a3b8) matching `--ha-muted`
  - White center dot (#e2e8f0)
- Converted to PNG: `icon.png` (512px), `icon-192.png` (192px), `icon-512.png` (512px)
- Created maskable variant (`icon-maskable.png`) with 72% scale in safe zone
- Generated `screenshot-wide.png` (1280x720) for install dialog

### Manifest Updated
- `app/views/pwa/manifest.json.erb`:
  - name: "Trip Journal", short_name: "Trip"
  - theme_color/background_color: `#0b1220`
  - Three icon entries: 192px, 512px, 512px maskable
  - Screenshot entry with `form_factor: "wide"`
  - Categories: travel, lifestyle

## Step 4: Service Worker

- Rewrote `app/views/pwa/service-worker.js`:
  - **Install:** Precaches offline fallback page, calls `skipWaiting()`
  - **Activate:** Cleans old caches (any `catalyst-*` cache not matching current version), calls `clients.claim()`
  - **Fetch handler:**
    - Skips non-GET requests
    - Skips Turbo Stream requests (`text/vnd.turbo-stream.html`)
    - Skips Action Cable WebSocket (`/cable`)
    - Skips non-HTTP and cross-origin requests
    - Network-first for HTML navigation (falls back to offline page)
    - Cache-first for static assets (CSS, JS, fonts, images)
  - Cache versioning via `CACHE_VERSION = "catalyst-v1"`

## Step 5: Application Layout

- Updated `app/views/layouts/application_layout.rb`:
  - Added `theme-color` meta tag (`#0b1220`)
  - Added `apple-mobile-web-app-status-bar-style` meta tag (`black-translucent`)
  - Changed `application-name` from "Catalyst" to "Trip Journal"
  - Updated `apple-touch-icon` href from `/icon.png` to `/icon-192.png`
  - Added `PwaInstallBanner` component render

## Step 6: Install Prompt

### Stimulus Controller
- Created `app/javascript/controllers/pwa_controller.js`:
  - Captures `beforeinstallprompt` event (defers prompt)
  - Tracks page visits in `sessionStorage`
  - Shows banner after 2+ page visits (engaged user)
  - `install()` action triggers the deferred prompt
  - `dismiss()` action hides banner and stores dismiss state in `sessionStorage`
  - Handles `appinstalled` event to clean up
  - Detects standalone mode to skip banner for already-installed apps

### Phlex Component
- Created `app/components/pwa_install_banner.rb`:
  - Fixed position bottom-right, z-50
  - Sky blue gradient styling matching flash toast pattern
  - Download icon (inline SVG)
  - "Install Trip Journal" heading + description
  - Install button (triggers `pwa#install`)
  - Dismiss button with Close icon (triggers `pwa#dismiss`)
  - Hidden by default (shown by Stimulus controller)

## Step 7: Offline Fallback Page

- Created `public/offline.html`:
  - Standalone HTML (no Rails dependencies)
  - Dark theme matching app design (#0b1220 background)
  - Centered layout with X icon, "You're offline" heading
  - "Try again" button that reloads the page
  - Uses Space Grotesk font family

## Step 8: Testing & Validation

### Automated Tests
- 376 non-system specs: **0 failures**
- 13 system specs: **0 failures**
- RuboCop lint: **0 offenses** (338 files)
- ERB Lint: **0 errors** (15 files)
- Overcommit hooks: **all passed** (warnings only for commit message line width)

### Runtime Verification
- `bin/cli app rebuild` — success
- `bin/cli app restart` — health check passed
- Manifest at `/manifest.json` — correct JSON with all branding
- Service worker at `/service-worker` — full JS loads
- Icons: `/icon-192.png`, `/icon-512.png`, `/icon-maskable.png` — all HTTP 200
- Screenshot: `/screenshot-wide.png` — HTTP 200
- Offline page at `/offline.html` — renders with dark theme
- Home page (logged out) — sidebar, hero section render correctly
- Login flow — email auth works (joel@acme.org)
- Home page (logged in) — sidebar shows all admin nav items
- Trips index — all trips visible with correct state badges
- PWA controller — mounted on page (`data-controller="pwa"` present)
- Meta tags verified: `theme-color`, `apple-mobile-web-app-status-bar-style`, `manifest`, `apple-touch-icon`
- Bullet N+1 — **no warnings** on any page
- Docker logs — **no Bullet warnings**

## Step 9: Push & PR

- Pushed `feature/phase-7-pwa-mobile`
- Created PR #34 → Closes #33

---

## Files Created (7)
1. `public/icon-192.png` — 192x192 app icon
2. `public/icon-512.png` — 512x512 app icon
3. `public/icon-maskable.png` — 512x512 maskable icon
4. `public/screenshot-wide.png` — 1280x720 screenshot for install dialog
5. `app/javascript/controllers/pwa_controller.js` — install prompt Stimulus controller
6. `app/components/pwa_install_banner.rb` — install prompt Phlex component
7. `public/offline.html` — offline fallback page

## Files Modified (4)
1. `app/views/pwa/manifest.json.erb` — updated with branding, icons, screenshot
2. `app/views/pwa/service-worker.js` — replaced skeleton with caching strategy
3. `app/views/layouts/application_layout.rb` — added meta tags, install banner
4. `public/icon.svg` — replaced red circle with compass icon
