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

## Bullet N+1 Query Audit

The `bullet` gem surfaces N+1 queries, unused eager loading, and counter cache opportunities in development. **Every page you visit during this review must be checked for Bullet alerts** — any "USE eager loading" alert is a defect that blocks merge.

Read `references/bullet_audit.md` for the per-page check commands, alert classification (USE / AVOID / Counter Cache), common fixes, and the reporting format.

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

## Step 15: PWA Verification

This app is a PWA. Buttons (`button_to` forms) use POST/PATCH/DELETE and behave differently than links — the service worker must not intercept them. **A page that renders correctly does NOT mean its buttons work.**

For any PR that touches service workers, JavaScript, Turbo, form/button behaviour, or the PWA manifest, read `references/pwa_verification.md` before finishing the review. It has the full button test matrix, service worker health checks, and manifest verification commands. For backend-only PRs that don't touch UI or JS, a quick sanity click on one button is usually enough.

## Step 16: MCP Server Verification

The app exposes 12 MCP tools at `POST /mcp`. The MCP server is a first-class feature — test it alongside the web UI on any PR that could affect it.

For PRs that touch `app/mcp/`, `app/tools/`, or any MCP-related code, read `references/mcp_verification.md` before finishing the review. It has the full tools/list sanity check, read/write/upload tool tests, state guard verification (reject write on finished trip), the auth guard check, and the verification criteria. For pure UI-only PRs that can't affect MCP, a minimal `tools/list` count sanity check is usually enough.

## Step 17: Mobile Viewport Verification

The app is a PWA used on mobile devices. Buttons and links that work on desktop frequently fail on mobile due to touch targets, overflow, or viewport issues. **Test at mobile width for every interactive element in any UI-touching PR.**

Read `references/mobile_verification.md` for the full mobile test matrix, viewport setup, mobile button tests, overflow detection commands, and the mobile-specific defect patterns. Skip only for pure backend/data PRs that don't render any new UI.

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
