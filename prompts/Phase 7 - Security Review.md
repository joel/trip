# Security Review -- feature/phase-7-pwa-mobile

**Date:** 2026-03-24
**Reviewer:** Claude (adversarial security pass)
**Branch:** `feature/phase-7-pwa-mobile`
**Diff base:** `main...HEAD`

## Summary

Phase 7 introduces PWA capabilities: a web app manifest, a service worker with cache-first/network-first fetch strategies, an offline fallback page, a Stimulus-driven install prompt controller, and a Phlex install banner component. No new gems or npm packages were added.

---

## Critical (must fix before merge)

No critical vulnerabilities found.

---

## Warning (should fix or consciously accept)

### W1: Inline event handler in offline.html bypasses future CSP

**File:** `public/offline.html:62`
**Code:** `<button onclick="window.location.reload()">Try again</button>`

The offline page uses an inline `onclick` handler. If a Content Security Policy is ever enabled (the CSP initializer at `config/initializers/content_security_policy.rb` is currently commented out but clearly intended for future use), `script-src 'self'` would block this inline handler, breaking the only interactive element on the offline page. Since the offline page is served from the service worker cache and is not rendered through Rails (no nonce injection), it cannot use CSP nonces.

**Recommendation:** Replace the inline handler with an unobtrusive script block at the bottom of the page:

```html
<button id="retry">Try again</button>
<script>
  document.getElementById("retry").addEventListener("click", function() {
    window.location.reload();
  });
</script>
```

This is still an inline `<script>` tag (which would also be blocked by a strict CSP), but it separates concerns. The real fix when CSP is enabled would be to either: (a) add a hash-based CSP exception for this specific script, or (b) accept that the offline page is a static file outside CSP scope. Either way, documenting this decision now prevents confusion later.

**Severity justification:** Warning, not Critical, because CSP is not currently enforced. But this will become a blocker the moment CSP is turned on.

### W2: Service worker cache has no size limit

**File:** `app/views/pwa/service-worker.js:57-73`

The cache-first strategy for static assets (`isStaticAsset`) caches every matched response indefinitely with no eviction policy. Over time, the cache can grow without bound as assets are fingerprinted by Propshaft on each deploy (each deploy produces new asset URLs that get cached while old entries remain).

The `activate` handler (line 16-26) only cleans caches whose key starts with `catalyst-` and does not match `STATIC_CACHE`. Since `STATIC_CACHE` is hardcoded to `catalyst-v1-static`, old entries within the same cache name are never evicted -- only entries cached under a different version key would be cleaned.

**Recommendation:** Either:
- Increment `CACHE_VERSION` on each deploy (e.g., embed a git SHA or timestamp via ERB: `const CACHE_VERSION = "catalyst-<%= Rails.application.config.asset_host || Time.now.to_i %>"`), so each deploy creates a new cache and the activate handler cleans the old one. Or:
- Add a maximum entry count and evict oldest entries when the limit is reached.

**Severity justification:** Warning. This is a resource leak, not a direct security vulnerability, but unbounded cache growth can be used as a client-side storage exhaustion vector on shared devices.

### W3: Cache version is static -- stale assets served after deploy

**File:** `app/views/pwa/service-worker.js:1`
**Code:** `const CACHE_VERSION = "catalyst-v1"`

The cache version never changes across deploys. Combined with `skipWaiting()` + `clients.claim()`, this means:
1. The service worker file itself will be re-fetched by the browser (byte-comparison check), so a new service worker will install on deploy.
2. But the activate handler only deletes caches that do not match `STATIC_CACHE` (`catalyst-v1-static`). Since the name stays the same, the old cached assets are never purged.
3. Cache-first means stale CSS/JS from a previous deploy will be served until the user hard-refreshes or clears site data.

This is the same root cause as W2 but the impact is different: users may see broken pages if the new HTML references asset URLs that differ from what is cached.

**Recommendation:** Make `CACHE_VERSION` dynamic. Since the service worker is rendered through ERB (Rails `PwaController` renders `pwa/service-worker` as a template), you can embed a deploy identifier:

```javascript
const CACHE_VERSION = "catalyst-<%= Rails.application.config.app_version || ENV.fetch('GIT_SHA', 'v1') %>"
```

This ensures each deploy triggers a full cache refresh via the activate handler's cleanup logic.

### W4: No CSP worker-src directive planned

**File:** `config/initializers/content_security_policy.rb` (commented out)

When CSP is eventually enabled, the policy will need a `worker-src 'self'` directive to allow the service worker to register. The commented-out template does not include `worker-src`. Without it, service worker registration will silently fail in browsers that enforce the default `worker-src` fallback chain.

**Recommendation:** Add a comment to the CSP initializer now documenting this requirement, so it is not missed when CSP is activated:

```ruby
# policy.worker_src :self  # Required for service worker registration (Phase 7)
```

---

## Informational (no action required)

### I1: Service worker fetch handler correctly excludes sensitive request types

The fetch handler (lines 30-73) has proper guards:
- Skips non-GET requests (line 34) -- POST/PUT/DELETE/PATCH are never cached.
- Skips Turbo Stream requests by checking `Accept: text/vnd.turbo-stream.html` (line 38) -- prevents caching Turbo Stream responses that would break Turbo navigation.
- Skips Action Cable WebSocket URLs containing `/cable` (line 39).
- Skips non-HTTP protocols like `chrome-extension://` (line 42).
- Only handles same-origin requests (line 47) -- cross-origin requests are never intercepted.
- Uses network-first for HTML navigation (line 50-54) -- ensures authenticated pages are always fetched fresh from the server, falling back to the generic offline page only when the network is unreachable.

This is a well-structured fetch handler that avoids the most common service worker security pitfalls (caching authenticated responses, intercepting cross-origin requests, caching mutation requests).

### I2: No XSS risk in offline.html

The offline page (`public/offline.html`) is a fully static file with no dynamic content, no user input, no query parameter reading, and no `innerHTML` usage. The inline SVG contains only hardcoded geometric shapes. There is no XSS surface.

### I3: Manifest does not expose sensitive information

The manifest (`app/views/pwa/manifest.json.erb`) contains only public branding information (app name, description, theme colors, icon paths, screenshot). No tokens, API keys, or internal URLs are exposed. The `scope` is set to `/` which is appropriate for the app's routing structure.

### I4: Phlex component is XSS-safe

The `PwaInstallBanner` component (`app/components/pwa_install_banner.rb`) uses Phlex's auto-escaping throughout. There are no calls to `unsafe_raw`, `html_safe`, or `raw`. All content is static string literals. The Stimulus data attributes use Phlex's standard `data:` hash syntax which is properly escaped.

### I5: Stimulus controller uses only browser-native APIs

The `pwa_controller.js` uses only the standard `beforeinstallprompt` API, `sessionStorage` for dismiss/visit state, and DOM class manipulation. No user input is processed, no data is sent to the server, and no `innerHTML` or `eval` is used. The `sessionStorage` keys (`pwa-banner-dismissed`, `pwa-page-visits`) store only boolean/integer values and cannot be exploited for injection.

### I6: PWA routes are unauthenticated by design

The manifest (`/manifest`) and service worker (`/service-worker`) routes are served by `Rails::PwaController` which inherits from `Rails::ApplicationController` (not the app's `ApplicationController`). This means:
- They bypass Rodauth authentication -- correct, because the browser must fetch the manifest and service worker before the user logs in.
- They bypass `ActionPolicy` authorization -- correct, these are public resources.
- They call `skip_forgery_protection` -- correct, these are GET-only routes serving static content.

This is the expected and correct behavior for PWA resources.

### I7: Service worker scope is appropriate

The service worker is registered from `/service-worker` (root-level path), which means its default scope is `/`. This matches the manifest's `scope: "/"`. The service worker can intercept all same-origin requests within this scope, which is the intended behavior for a PWA service worker.

### I8: No new dependencies added

No changes to `Gemfile`, `Gemfile.lock`, `package.json`, or `yarn.lock`. The implementation uses only Rails built-in PWA support and standard browser APIs.

---

## Not applicable

| Category | Reason |
|---|---|
| **Authentication & Authorization** | No new routes requiring auth were added. The PWA routes (`/manifest`, `/service-worker`) are intentionally public (see I6). No new controllers or actions were introduced in the app's controller hierarchy. |
| **Strong Parameters / Mass Assignment** | No controller actions accept user params in this diff. |
| **Database / Query Safety** | No database queries or models were added or modified. |
| **File Uploads** | No file upload functionality was added. |
| **Secrets & Configuration** | No secrets, tokens, or credentials are present in the diff. The manifest and service worker contain only public values. |
| **Data Exposure** | No private data (tokens, password digests, internal state) is exposed in any of the new views or assets. |
| **Authorization bypass via direct HTTP** | The only new server-rendered content is the manifest (public JSON) and service worker (public JS). Neither exposes protected resources. |

---

## Checklist Summary

| Check | Status |
|---|---|
| Service worker skips non-GET requests | Pass |
| Service worker skips Turbo Stream requests | Pass |
| Service worker skips cross-origin requests | Pass |
| Service worker uses network-first for HTML | Pass |
| No cached authenticated responses | Pass |
| Offline page free of XSS | Pass |
| Offline page inline handler vs future CSP | Warning (W1) |
| Manifest free of sensitive data | Pass |
| Phlex component uses auto-escaping | Pass |
| No `unsafe_raw` / `html_safe` / `raw` | Pass |
| No new dependencies | Pass |
| No hardcoded secrets | Pass |
| Cache eviction strategy | Warning (W2, W3) |
| CSP compatibility for worker-src | Warning (W4) |

---

## Verdict

**The branch is safe to merge.** There are no critical vulnerabilities. The four warnings (W1-W4) are all forward-looking concerns related to future CSP enforcement and cache management hygiene. None of them represent an exploitable vulnerability in the current deployment. They should be addressed either in this PR or tracked as a follow-up issue for when CSP is enabled and the deploy pipeline matures.
