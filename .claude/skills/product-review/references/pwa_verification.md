# PWA Verification

The app is a Progressive Web App. Buttons (`button_to` forms) behave differently than links (`link_to`) because they use POST/PATCH/DELETE requests. The service worker must not intercept these. Test buttons explicitly — do NOT assume a page that renders is also interactive.

## Button vs Link Distinction

- **Links** (`<a href>`) = GET requests = navigation. These are handled by Turbo Drive.
- **Buttons** (`<form method="post">`) = POST/PATCH/DELETE = mutations. These include reactions, delete, sign out, checklist toggles, comment post, and form submits.

If links work but buttons don't, the likely cause is:
1. Service worker intercepting non-GET requests (check `if (request.method !== "GET") return` in `app/views/pwa/service-worker.js.erb`)
2. Stale cached JavaScript missing Turbo or Stimulus controllers
3. CSRF token mismatch from cached HTML

## PWA Button Tests

After logging in, test every button type on a **writable trip** (started state, e.g. Iceland Road Trip):

```bash
# 1. Reaction button (POST via button_to)
# Navigate to a journal entry on a started trip
# Click a reaction emoji button (e.g. thumbsup)
# Verify: count increments, no error, no redirect

# 2. Comment Post button (POST via form_with)
# Fill the comment textarea, click Post
# Verify: comment appears via Turbo Stream, form resets

# 3. Comment Delete button (DELETE via button_to)
# Click Delete on an existing comment
# Verify: comment removed via Turbo Stream

# 4. Comment Edit (details toggle + PATCH via form_with)
# Click Edit on a comment, modify text, click Save
# Verify: comment updates via Turbo Stream

# 5. Journal Entry Delete button (DELETE via button_to)
# On a journal entry page, click Delete
# Verify: redirects to trip show, entry removed

# 6. Checklist toggle (PATCH via button_to)
# Navigate to a checklist, click a checkbox item
# Verify: item toggles without page reload

# 7. Trip state transition (POST via button_to)
# On a trip in planning state (Barcelona), click Start
# Verify: trip transitions to started state

# 8. Sign out button (POST/DELETE)
# Click Sign out in the sidebar
# Verify: session ends, redirects to home
```

## Service Worker Health Check

```bash
# Check service worker is registered and active
agent-browser eval "navigator.serviceWorker.ready.then(r => r.active?.state || 'no-sw')"

# Check service worker skips non-GET
agent-browser eval "fetch('/service-worker').then(r => r.text()).then(t => t.includes('request.method !== \"GET\"') ? 'GOOD: skips non-GET' : 'BAD: may intercept POSTs')"

# Check no stale caches
agent-browser eval "caches.keys().then(k => k.join(', '))"
```

## PWA Manifest Check

```bash
agent-browser eval "fetch('/manifest.json').then(r => r.json()).then(m => JSON.stringify({name: m.name, display: m.display, start_url: m.start_url}))"
```

Verify: `display` is `standalone`, `start_url` is `/`, `name` is set.
