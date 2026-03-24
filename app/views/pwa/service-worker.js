const CACHE_VERSION = "catalyst-<%= ENV.fetch('GIT_SHA', 'v1') %>"
const STATIC_CACHE = `${CACHE_VERSION}-static`
const OFFLINE_URL = "/offline.html"

const PRECACHE_URLS = [OFFLINE_URL]

// Install: precache offline page
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_URLS))
  )
  self.skipWaiting()
})

// Activate: clean old caches
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith("catalyst-") && key !== STATIC_CACHE)
          .map((key) => caches.delete(key))
      )
    )
  )
  self.clients.claim()
})

// Fetch: network-first for HTML, cache-first for static assets
self.addEventListener("fetch", (event) => {
  const { request } = event

  // Skip non-GET requests
  if (request.method !== "GET") return

  // Skip WebSocket, Turbo Stream, and Action Cable requests
  const accept = request.headers.get("Accept") || ""
  if (accept.includes("text/vnd.turbo-stream.html")) return
  if (request.url.includes("/cable")) return

  // Skip Chrome extension and browser internal requests
  if (!request.url.startsWith("http")) return

  const url = new URL(request.url)

  // Only handle same-origin requests
  if (url.origin !== self.location.origin) return

  // Network-first for HTML navigation requests
  if (request.mode === "navigate" || accept.includes("text/html")) {
    event.respondWith(
      fetch(request).catch(() => caches.match(OFFLINE_URL))
    )
    return
  }

  // Cache-first for static assets (CSS, JS, fonts, images)
  if (isStaticAsset(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached

        return fetch(request).then((response) => {
          if (response.ok) {
            const clone = response.clone()
            caches.open(STATIC_CACHE).then((cache) => cache.put(request, clone))
          }
          return response
        })
      })
    )
    return
  }
})

function isStaticAsset(pathname) {
  return /\.(css|js|woff2?|ttf|eot|png|jpe?g|gif|svg|ico|webp)(\?|$)/.test(pathname)
}
