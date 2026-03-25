---
name: product-review
description: Use after committing code changes to perform mandatory live product verification. Triggers when the user says "product review", "test live", "runtime test", "verify live", "browser test", or after completing a feature/fix. Rebuilds the app, restarts services, and visually verifies all pages with agent-browser using seed data.
---

# Product Review Workflow

Perform live product verification of the application after code changes. This ensures the app actually works in the Docker environment, not just in unit tests.

## When to Run

Run this workflow:
- After all code changes are committed and tests pass
- Before pushing a branch or creating a PR
- When the user asks to "test live" or "verify in browser"

## Prerequisites

- `agent-browser` CLI installed and available
- Docker services running (app + mail)
- The `bin/cli` command available in the project root

## Seed Data Reference

The database has comprehensive seed data (`db/seeds.rb`). Use it — do NOT create test accounts from scratch.

### Seeded Users

| Email | Name | Role | Password |
|-------|------|------|----------|
| `joel@acme.org` | Joel Azemar | superadmin | Passwordless (email auth) |
| `alice@acme.org` | Alice Martin | contributor | Passwordless |
| `bob@acme.org` | Bob Chen | contributor | Passwordless |
| `carol@acme.org` | Carol Nguyen | contributor | Passwordless |
| `dave@acme.org` | Dave Wilson | viewer | Passwordless |
| `eve@acme.org` | Eve Santos | viewer | Passwordless |

### Seeded Trips (one per state)

| Trip Name | State | Created By | Members |
|-----------|-------|-----------|---------|
| Japan Spring Tour | finished | joel | joel, alice, bob (contributors), dave, eve (viewers) |
| Iceland Road Trip | started | alice | alice, bob, carol (contributors), dave (viewer) |
| Weekend in Barcelona | planning | bob | bob, alice (contributors), eve (viewer) |
| Norway Fjords | cancelled | joel | joel, carol (contributors) |
| Patagonia Trek | archived | carol | carol, alice (contributors), bob (viewer) |

### Seeded Content

- **11 journal entries** with rich text bodies, locations, and images (Japan: 5, Iceland: 3, Patagonia: 3)
- **12 comments** from various users across entries
- **25 reactions** on trips, entries, and comments (all 6 emojis used)
- **3 checklists** (Japan: fully completed, Iceland: partial, Barcelona: mostly empty)
- **3 access requests** (pending, approved, rejected)
- **3 invitations** (pending, accepted, expired)
- **3 exports** (completed with file, pending, failed)

### Login Helper

To log in as any seeded user via email auth:

```bash
# 1. Clear old emails
curl -sk -X DELETE https://mail.workeverywhere.docker/messages

# 2. Go to login page, fill email, submit
agent-browser open https://catalyst.workeverywhere.docker/login && agent-browser wait --load networkidle
agent-browser snapshot -i  # Find email field and Login button refs
agent-browser fill @eN "joel@acme.org"
agent-browser click @eM  # Login button
agent-browser wait --load networkidle

# 3. Get login link from email and navigate
sleep 2
LOGIN_KEY=$(curl -sk https://mail.workeverywhere.docker/messages/1.plain | grep -oP 'key=\K\S+')
agent-browser open "https://catalyst.workeverywhere.docker/email-auth?key=$LOGIN_KEY" && agent-browser wait --load networkidle

# 4. Click the Login button on the email-auth page
agent-browser snapshot -i  # Find Login button ref
agent-browser click @eN  # Login button
agent-browser wait --load networkidle
```

## Workflow

### Step 1: Rebuild and Restart

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Wait for the health check to pass in the restart output before proceeding.

### Step 2: Verify Home Page (Logged Out)

```bash
agent-browser open https://catalyst.workeverywhere.docker/ && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-home.png
```

Verify:
- Sidebar navigation renders (Overview, Dark mode toggle, Sign in, Create account)
- Hero section with "Welcome home" heading
- Access card with Request Access / Sign in buttons

### Step 3: Log In as Admin

Use the login helper above with `joel@acme.org`. After login:

```bash
agent-browser screenshot /tmp/rt-home-logged-in.png
```

Verify:
- Sidebar shows: Trips, Users, Requests, Invitations, My account, Sign out
- Home page shows trip and user cards

### Step 4: Verify Trips Index (All States)

```bash
agent-browser open https://catalyst.workeverywhere.docker/trips && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-trips.png
```

Verify all 5 trips are visible with correct state badges:
- Japan Spring Tour — **Finished** (indigo badge)
- Iceland Road Trip — **Started** (emerald badge)
- Weekend in Barcelona — **Planning** (sky badge)
- Norway Fjords — **Cancelled** (red badge)
- Patagonia Trek — **Archived** (zinc badge)

### Step 5: Verify Trip Show + Journal Entries

Navigate to a trip with entries (Japan Spring Tour or Iceland Road Trip):

```bash
# Get trip ID
TRIP_ID=$(docker exec catalyst-app-dev bin/rails runner "puts Trip.find_by(name: 'Japan Spring Tour').id" 2>&1 | tail -1)
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-trip-show.png
```

Verify:
- Trip name, description, state badge, date range
- Header buttons: Edit, Members, Checklists, Exports, Delete, Back to trips
- Journal entries listed with names, dates, locations
- State transition buttons (if applicable for the trip state)

### Step 6: Verify Journal Entry with Images, Comments, Reactions

```bash
ENTRY_ID=$(docker exec catalyst-app-dev bin/rails runner "puts JournalEntry.find_by(name: 'Arrival in Tokyo').id" 2>&1 | tail -1)
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/journal_entries/$ENTRY_ID" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-entry.png
```

Verify:
- Rich text body with formatting (bold, italic)
- Images render (photos from picsum.photos)
- Reaction emojis visible with counts
- Comments from Alice Martin and Dave Wilson visible
- Comment form present

Scroll to bottom to see all content:
```bash
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)" && sleep 1 && agent-browser screenshot /tmp/rt-entry-bottom.png
```

### Step 7: Verify Exports Page

```bash
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/exports" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-exports.png
```

Verify:
- Export cards visible with status badges (Completed, Pending, Failed)
- Download button on completed export
- "New export" button present

### Step 8: Verify Checklists

```bash
CHECKLIST_ID=$(docker exec catalyst-app-dev bin/rails runner "puts Checklist.find_by(name: 'Packing List').id" 2>&1 | tail -1)
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/checklists/$CHECKLIST_ID" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-checklist.png
```

Verify:
- Sections visible (Clothing, Electronics, Documents)
- Items with checkboxes — Japan's checklist should be fully completed

### Step 9: Verify Members Page

```bash
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/members" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-members.png
```

Verify:
- All 5 members shown (Joel, Alice, Bob, Dave, Eve)
- Roles displayed (contributor/viewer)

### Step 10: Verify Admin Pages

```bash
# Users index (6 users)
agent-browser open https://catalyst.workeverywhere.docker/users && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-users.png

# Access requests (3 — pending, approved, rejected)
agent-browser open https://catalyst.workeverywhere.docker/access_requests && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-access-requests.png

# Invitations (3 — pending, accepted, expired)
agent-browser open https://catalyst.workeverywhere.docker/invitations && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-invitations.png
```

Verify:
- Users index shows 6 user cards
- Access requests show all 3 states
- Invitations show all 3 states

### Step 11: Test Dark Mode

```bash
agent-browser snapshot -i
# Find and click the "Toggle dark mode" button
agent-browser click @eN  # Dark mode toggle
agent-browser wait 500 && agent-browser screenshot /tmp/rt-dark-mode.png
```

Verify: dark background, light text, cards adapt correctly.

### Step 12: Test as Non-Admin User (optional but recommended)

Log out and log in as `alice@acme.org` (contributor) to verify:
- Trips index shows only Alice's trips (not all 5)
- No Users/Requests/Invitations nav items
- Can view and interact with trip content she's a member of

### Step 13: Cleanup

```bash
agent-browser close
```

## Step 14: Verify User Journeys (Critical)

Page rendering alone does not guarantee correctness. Test multi-step user journeys including downstream effects.

### Access & Onboarding Journey

```bash
# 1. Submit access request (logged out)
agent-browser open https://catalyst.workeverywhere.docker/request-access
# Fill email, submit, verify flash toast

# 2. Check admin notification email
curl -sk https://mail.workeverywhere.docker/messages | python3 -c "import json,sys; [print(m['id'],m['subject'],m['recipients']) for m in json.load(sys.stdin)]"

# 3. Log in as admin, approve the request
agent-browser open https://catalyst.workeverywhere.docker/access_requests
# Click Approve

# 4. Verify invitation email was AUTO-SENT to the requester
curl -sk https://mail.workeverywhere.docker/messages | python3 -c "import json,sys; [print(m['id'],m['subject'],m['recipients']) for m in json.load(sys.stdin)]"

# 5. Extract invitation token and navigate to signup
curl -sk https://mail.workeverywhere.docker/messages/<N>.plain

# 6. VERIFY: email field is pre-filled and read-only
agent-browser open "https://catalyst.workeverywhere.docker/create-account?invitation_token=<TOKEN>"
agent-browser eval 'document.querySelector("#login")?.value'
agent-browser eval 'document.querySelector("#login")?.readOnly'

# 7. Submit and verify account creation succeeds
```

### Shell Tips

- **Checking emails:** `curl -sk https://mail.workeverywhere.docker/messages` returns JSON array
- **Reading email body:** `curl -sk https://mail.workeverywhere.docker/messages/<ID>.plain`
- **Clearing emails:** `curl -sk -X DELETE https://mail.workeverywhere.docker/messages`
- **Running Rails code in container:** Use heredoc for shell safety:
  ```bash
  cat > /tmp/script.rb <<'RUBY'
  user = User.find_by(email: "test@example.com")
  user.save!
  RUBY
  docker exec -i catalyst-app-dev bin/rails runner - < /tmp/script.rb
  ```

## Bullet N+1 Query Audit (Mandatory)

The project uses the `bullet` gem to detect N+1 queries, unused eager loading, and counter cache opportunities. In development mode, Bullet is configured with:
- `alert = true` — JavaScript alert popup on every page with issues
- `add_footer = true` — HTML footer injected at the bottom of every page
- `console = true` — warnings logged to browser console
- `rails_logger = true` — warnings logged to Rails log

**On every page you visit during the review, you MUST check for Bullet alerts.** Bullet alerts are N+1 query problems that degrade performance and must be fixed before merge.

### How to Check for Bullet Alerts

After loading each page, run:

```bash
# Check for Bullet footer in page HTML
agent-browser eval "document.getElementById('bullet-footer')?.innerText || 'No Bullet warnings'"

# Check for Bullet alerts in browser console
agent-browser eval "window.__bullet_alerts || 'No alerts'"
```

Also check the Docker logs after browsing:

```bash
docker logs catalyst-app-dev --tail 100 2>&1 | grep -i "bullet\|USE eager\|N+1\|Counter cache"
```

### Common Bullet Findings and Fixes

| Bullet Message | Meaning | Fix |
|----------------|---------|-----|
| `USE eager loading detected: Model => [:association]` | N+1 query — each item triggers a separate query for the association | Add `.includes(:association)` to the controller query |
| `AVOID eager loading detected: Model => [:association]` | You're eager-loading an association that's never used on this page | Remove the `.includes(:association)` from the query |
| `Need Counter Cache: Model => [:association]` | Calling `.count` or `.size` on an association in a loop | Add `counter_cache: true` to the `belongs_to` or use `.size` with eager loading |

### Reporting Bullet Issues

List every Bullet warning in the report under a dedicated section:

```
## Bullet N+1 Alerts

| Page | Alert | Severity |
|------|-------|----------|
| /trips | USE eager loading: Trip => [:trip_memberships] | Must fix |
| /trips/:id | None | Clean |
| /trips/:id/journal_entries/:id | USE eager loading: JournalEntry => [:comments] | Must fix |
```

**Every "USE eager loading" alert is a defect that must be fixed.** Add `.includes(...)` or `.preload(...)` in the relevant controller action.

**"AVOID eager loading" alerts are warnings** — remove the unnecessary `.includes(...)`.

## Handling Failures

If any page shows an error:
1. Read the error message from the screenshot
2. Identify the root cause
3. Fix the code
4. Re-run `bundle exec rake` to ensure tests pass
5. Commit the fix
6. Restart the app with `bin/cli app restart`
7. Re-verify the failing page

If a multi-step journey fails silently:
1. Check the Rails logs: `docker logs catalyst-app-dev --tail 50`
2. Check if the event was emitted and subscriber dispatched the job
3. Check if the mailer was called (look for email in MailCatcher)
4. Fix the gap in the event/subscriber/job chain

## Step 15: PWA Verification (Mandatory)

The app is a Progressive Web App. Buttons (`button_to` forms) behave differently than links (`link_to`) because they use POST/PATCH/DELETE requests. The service worker must not intercept these. Test buttons explicitly -- do NOT assume a page that renders is also interactive.

### Button vs Link Distinction

- **Links** (`<a href>`) = GET requests = navigation. These are handled by Turbo Drive.
- **Buttons** (`<form method="post">`) = POST/PATCH/DELETE = mutations. These include reactions, delete, sign out, checklist toggles, comment post, and form submits.

If links work but buttons don't, the likely cause is:
1. Service worker intercepting non-GET requests (check `if (request.method !== "GET") return` in `app/views/pwa/service-worker.js.erb`)
2. Stale cached JavaScript missing Turbo or Stimulus controllers
3. CSRF token mismatch from cached HTML

### PWA Button Tests

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

### Service Worker Health Check

```bash
# Check service worker is registered and active
agent-browser eval "navigator.serviceWorker.ready.then(r => r.active?.state || 'no-sw')"

# Check service worker skips non-GET
agent-browser eval "fetch('/service-worker').then(r => r.text()).then(t => t.includes('request.method !== \"GET\"') ? 'GOOD: skips non-GET' : 'BAD: may intercept POSTs')"

# Check no stale caches
agent-browser eval "caches.keys().then(k => k.join(', '))"
```

### PWA Manifest Check

```bash
agent-browser eval "fetch('/manifest.json').then(r => r.json()).then(m => JSON.stringify({name: m.name, display: m.display, start_url: m.start_url}))"
```

Verify: `display` is `standalone`, `start_url` is `/`, `name` is set.

## Step 16: MCP Server Verification (Mandatory)

The app exposes 12 MCP tools at `POST /mcp`. The MCP server is stateless -- every request is independent, no initialize handshake required. Test it alongside the web UI.

### MCP Connection

```bash
# Set the API key from .env.development
MCP_KEY=$(grep MCP_API_KEY .env.development | cut -d= -f2)

# Quick health check -- list all tools
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}' \
  | python3 -c "import json,sys; tools=json.load(sys.stdin)['result']['tools']; print(f'{len(tools)} tools'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

Expected: 12 tools listed.

### MCP Tool Tests

Test each category of tool against the live Docker app:

```bash
# 1. Read operation -- get trip status (auto-resolves to started trip)
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_trip_status","arguments":{}}}' \
  | python3 -m json.tool

# 2. Read operation -- list journal entries
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"list_journal_entries","arguments":{"limit":3}}}' \
  | python3 -m json.tool

# 3. Write operation -- create a journal entry on the started trip
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"4","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"MCP Test Entry","entry_date":"2026-03-25","body":"<p>Created by product review.</p>","location_name":"Docker"}}}' \
  | python3 -m json.tool

# 4. Upload image -- use a real image (not a stub!)
B64_IMG=$(curl -sL "https://picsum.photos/200/150.jpg" | base64 -w0)
ENTRY_ID=<uuid-from-step-3>
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"5\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"$ENTRY_ID\",\"images\":[{\"data\":\"$B64_IMG\",\"filename\":\"review_test.jpg\"}]}}}" \
  | python3 -m json.tool

# 5. Verify the uploaded image renders in the browser
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/journal_entries/$ENTRY_ID" && agent-browser wait --load networkidle
agent-browser eval "document.querySelectorAll('img[alt]').length"  # Count rendered images
agent-browser screenshot /tmp/rt-mcp-entry.png

# 6. State guard -- reject write on finished trip
FINISHED_ENTRY_ID=$(docker exec catalyst-app-dev bin/rails runner "puts Trip.find_by(state: :finished).journal_entries.first.id" 2>&1 | tail -1)
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"6\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"$FINISHED_ENTRY_ID\",\"images\":[{\"data\":\"$B64_IMG\"}]}}}" \
  | python3 -m json.tool
# Expected: isError: true, "not writable"

# 7. Auth guard -- reject without API key
curl -s -w "\nHTTP: %{http_code}\n" https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"7","method":"tools/list"}'
# Expected: HTTP 401
```

### MCP Verification Criteria

- All 12 tools listed
- Read tools return correct data matching seed data
- Write tools create records visible in the web UI
- Uploaded images render in the browser (not broken/stub)
- State guards reject writes on non-writable trips
- Auth rejects requests without valid API key
- Invalid tool name returns JSON-RPC "Method not found"

## Step 17: Mobile Viewport Verification (Mandatory)

The app is a PWA used on mobile devices. Buttons and links that work on desktop may fail on mobile due to touch targets, overflow, or viewport issues. **Test at mobile width for every interactive element.**

### Mobile Setup

```bash
# Set mobile viewport (iPhone 14 Pro dimensions)
agent-browser eval "
  Object.defineProperty(navigator, 'userAgent', {value: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'});
"
agent-browser viewport 393 852
```

### Mobile Page Tests

Test every page at mobile width. Look for:
- **Buttons/links cut off or overlapping** -- tap targets must be >= 44x44px
- **Horizontal scrolling** -- no content should overflow the viewport
- **Sidebar behavior** -- must collapse to hamburger/overlay, not push content off-screen
- **Forms** -- inputs must be full-width, labels visible, submit buttons reachable
- **Cards** -- must stack vertically, not overlap

```bash
# Home page (logged out)
agent-browser open https://catalyst.workeverywhere.docker/ && agent-browser wait --load networkidle
agent-browser screenshot /tmp/rt-mobile-home.png

# Login page
agent-browser open https://catalyst.workeverywhere.docker/login && agent-browser wait --load networkidle
agent-browser screenshot /tmp/rt-mobile-login.png

# After login -- trips index
agent-browser screenshot /tmp/rt-mobile-trips.png

# Trip show
agent-browser screenshot /tmp/rt-mobile-trip-show.png

# Journal entry (images, comments, reactions)
agent-browser screenshot /tmp/rt-mobile-entry.png

# Scroll to comments and reaction buttons
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)" && sleep 1
agent-browser screenshot /tmp/rt-mobile-entry-bottom.png
```

### Mobile Button Tests (Critical)

Every button must be tappable at mobile width. Test these explicitly:

```bash
# 1. Sidebar toggle (hamburger menu)
agent-browser snapshot -i  # Find hamburger/menu button
agent-browser click @eN  # Tap hamburger
agent-browser screenshot /tmp/rt-mobile-sidebar.png

# 2. Navigation links in mobile sidebar
# Tap each nav item and verify navigation works

# 3. Sign in button on home page
# Must be visible and tappable without scrolling

# 4. Reaction emoji buttons
# Must be tappable (not too small, not overlapping)

# 5. Comment form submit
# Textarea and Post button must be usable

# 6. Checklist toggle checkboxes
# Must be tappable at mobile width

# 7. Dark mode toggle
# Must be accessible in mobile sidebar/header
```

### Mobile-Specific Defects to Watch For

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Button doesn't respond to tap | Touch target too small (< 44px), or overlapping element intercepts tap | Add `min-h-[44px] min-w-[44px]` or fix z-index |
| Link works on desktop, not mobile | `hover:` styles hiding the clickable area, or `pointer-events-none` on a parent | Use `@media (hover: hover)` for hover effects |
| Horizontal scroll on mobile | Fixed-width element or `whitespace-nowrap` without `overflow-hidden` | Add `overflow-hidden` or `max-w-full` |
| Sidebar pushes content off-screen | Sidebar not using `fixed`/`absolute` positioning on mobile | Use responsive `lg:` breakpoint for sidebar layout |
| Form input zooms on iOS | Font size < 16px on input | Set `text-base` (16px) on form inputs |

### Viewport Overflow Check

After loading each page at mobile width, run:

```bash
# Check for horizontal overflow
agent-browser eval "document.documentElement.scrollWidth > document.documentElement.clientWidth ? 'OVERFLOW: ' + document.documentElement.scrollWidth + ' > ' + document.documentElement.clientWidth : 'OK: no overflow'"
```

**Any overflow is a defect.**

## Checklist

Report results using this checklist:

```
## Product Review Results

### Infrastructure
- [ ] App rebuild succeeds
- [ ] App restart health check passes
- [ ] Mail service running

### Desktop Pages
- [ ] Home page (logged out) renders correctly
- [ ] Login via email auth works (joel@acme.org)
- [ ] Home page (logged in) renders correctly
- [ ] Trips index shows all 5 trips with correct state badges
- [ ] Trip show page renders (entries, buttons, state transitions)
- [ ] Journal entry renders (rich text, images, comments, reactions)
- [ ] Exports page renders (completed/pending/failed badges)
- [ ] Checklist page renders (sections, items, completion states)
- [ ] Members page renders (contributor/viewer roles)
- [ ] Users index shows 6 users
- [ ] Access requests page shows 3 states
- [ ] Invitations page shows 3 states
- [ ] Dark mode toggle works
- [ ] No runtime errors on any page
- [ ] No Bullet N+1 alerts on any page

### User Journeys
- [ ] Access request → approval → invitation email journey works

### MCP Server
- [ ] MCP tools/list returns 12 tools
- [ ] MCP get_trip_status returns correct data
- [ ] MCP create_journal_entry creates entry visible in web UI
- [ ] MCP upload_journal_images attaches image that renders in browser
- [ ] MCP state guards reject writes on non-writable trips
- [ ] MCP rejects unauthenticated requests (401)

### PWA & Buttons (Desktop)
- [ ] Reaction button works (toggles emoji count)
- [ ] Comment Post button works (appends via Turbo Stream)
- [ ] Comment Delete button works (removes via Turbo Stream)
- [ ] Comment Edit works (inline form, saves via Turbo Stream)
- [ ] Checklist toggle works
- [ ] Sign out button works
- [ ] Service worker skips non-GET requests
- [ ] No stale caches blocking functionality

### Mobile (393x852 viewport)
- [ ] No horizontal overflow on any page
- [ ] Sidebar collapses and hamburger menu works
- [ ] Home page buttons tappable (Sign in, Request Access)
- [ ] Login form usable (input visible, submit tappable)
- [ ] Trips index cards stack properly
- [ ] Trip show buttons tappable (Edit, Members, etc.)
- [ ] Journal entry images scale to viewport
- [ ] Reaction buttons tappable (>= 44px touch target)
- [ ] Comment form usable (textarea + Post button)
- [ ] Checklist toggles tappable
- [ ] Dark mode toggle accessible on mobile
- [ ] Navigation links work from mobile sidebar
- [ ] Sign out works on mobile
```
