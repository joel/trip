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
2. `app/views/pwa/service-worker.js.erb` — replaced skeleton with caching strategy
3. `app/views/layouts/application_layout.rb` — added meta tags, install banner
4. `public/icon.svg` — replaced red circle with compass icon

---

## Step 10: Review Fixes (2026-03-24)

All 5 review agents ran in parallel (QA, Security, UX, UI Polish, UI Designer).
Reports written to `prompts/Phase 7 - {QA,Security,UX,UI Polish,UI Designer} Review.md`.

### Critical/Broken Fixes Applied

| ID | Finding | Fix |
|----|---------|-----|
| D1 | Service worker never registered | Added `navigator.serviceWorker.register()` to `application.js` |
| B2 | Sidebar doesn't collapse on mobile | Added `@media (max-width: 767px)` CSS with fixed sidebar and margin-left on main |
| JIT | Tailwind sky classes not compiled | Docker rebuild compiles all new classes |

### High-Priority Fixes Applied

| ID | Finding | Fix |
|----|---------|-----|
| F1-F3 | Touch targets below 44px | Dismiss button: h-7 w-7 → h-11 w-11; Install button: px-3 py-1.5 → px-4 py-2.5; Offline button: padding increased + min-height: 44px |
| F4/E1 | sessionStorage for dismiss | Changed to localStorage for persistent dismiss state |
| F5 | Offline X icon = "error" | Replaced with WiFi-off icon (arcs + slash + dot) |
| F6 | Offline dark-only | Added @media (prefers-color-scheme: light) with light tokens |
| F7/E6 | No iOS install guidance | Added iOS detection + "Tap Share, then Add to Home Screen" instructions |
| E4/W2/W3 | Static cache version | ERB-embedded `ENV['GIT_SHA']` with v1 fallback; renamed to .js.erb |
| E5 | No narrow screenshot | Generated 750x1334 screenshot-narrow.png, added to manifest |
| W1 | Inline onclick in offline.html | Replaced with unobtrusive `addEventListener` script |
| W4 | No worker-src CSP comment | Added `policy.worker_src :self` comment to CSP initializer |

### UI/Polish Fixes Applied

| Finding | Fix |
|---------|-----|
| No entrance animation | Replaced hidden toggle with opacity-0/translate-y-4 → opacity-100/translate-y-0 |
| Banner title too small | Changed text-sm → text-base for visual hierarchy |
| Missing aria_label on install | Added aria_label: "Install Trip Journal" |
| Mobile banner positioning | Added left-6 sm:left-auto for full-width on mobile |
| Missing focus styles (offline) | Added :focus-visible outline on Try again button |
| Missing theme-color (offline) | Added meta name="theme-color" |
| Missing reduced-motion (offline) | Added @media (prefers-reduced-motion: reduce) |
| Space Grotesk font ref | Removed (font never loads offline) |
| UI library not synced | Created pwa_install_banner.yml, updated SKILL.md table, regenerated index |

### Additional Files Created
8. `public/screenshot-narrow.png` — 750x1334 mobile screenshot
9. `ui_library/pwa_install_banner.yml` — UI library registry entry

### Additional Files Modified
5. `app/javascript/controllers/application.js` — added SW registration
6. `app/assets/tailwind/application.css` — added mobile sidebar rules
7. `config/initializers/content_security_policy.rb` — added worker-src comment
8. `.claude/skills/ui-designer/SKILL.md` — added PwaInstallBanner to component table
9. `ui_library/index.html` — regenerated with new component
