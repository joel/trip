---
name: qa-review
description: Use this skill after product-review completes to perform structured quality assurance on the full feature or fix — checking edge cases, boundary conditions, and regression risk that automated tests may not cover. Trigger when the user says "qa review", "qa check", "edge case review", or after any phase completes before the PR is merged. This skill is adversarial: its job is to break the feature, not validate it. Always prefer testing in the live Docker environment over reading code.
---

# QA Review

Perform structured quality assurance on the changes in the current branch. This is an adversarial pass — attempt to break the feature through edge cases, unexpected input, and user behaviour the implementation agent didn't anticipate.

## Project Context

- **App URL:** `https://catalyst.workeverywhere.docker/`
- **Mail URL:** `https://mail.workeverywhere.docker/`
- **Container:** `catalyst-app-dev`
- **CLI:** Use `bin/cli` for app/service management (`bin/cli app rebuild`, `bin/cli app restart`, `bin/cli mail start`)
- **Ruby commands outside container:** Prefix with `mise x --` (e.g., `mise x -- bundle exec rspec`)
- **Auth framework:** Rodauth (login, create-account, verify-account, email-auth, webauthn)
- **Authorization:** ActionPolicy (`authorize!` in controllers, `allowed_to?` in views)
- **Views:** Phlex components (not ERB)

## Seed Data Reference

The database has comprehensive seed data (`db/seeds.rb`). Use these seeded records for testing — do NOT create test data from scratch unless testing creation flows.

### Users (all passwordless — email auth via MailCatcher)

| Email | Name | App Role | Purpose |
|-------|------|----------|---------|
| `joel@acme.org` | Joel Azemar | superadmin | Full admin access — use for admin-only page tests |
| `alice@acme.org` | Alice Martin | contributor | Member of Japan, Iceland, Barcelona, Patagonia — use for contributor tests |
| `bob@acme.org` | Bob Chen | contributor | Member of Japan, Iceland, Barcelona, Patagonia — use for contributor tests |
| `carol@acme.org` | Carol Nguyen | contributor | Member of Iceland, Norway, Patagonia — use for contributor tests |
| `dave@acme.org` | Dave Wilson | viewer | Viewer on Japan, Iceland — use for viewer permission tests |
| `eve@acme.org` | Eve Santos | viewer | Viewer on Japan, Barcelona — use for viewer permission tests |

### Trips (one per state — test state-dependent behavior)

| Trip | State | Created By | Key Properties |
|------|-------|-----------|----------------|
| Japan Spring Tour | **finished** | joel | 5 entries, images, comments, reactions, checklist (fully done), 3 exports |
| Iceland Road Trip | **started** | alice | 3 entries, images, comments, checklist (partial), writable |
| Weekend in Barcelona | **planning** | bob | No entries, checklist (mostly empty), writable |
| Norway Fjords | **cancelled** | joel | No entries, not writable, not commentable |
| Patagonia Trek | **archived** | carol | 3 entries, images, comments, no writable/commentable |

### Key State Rules

| State | `writable?` | `commentable?` | Can create entries? | Can create exports? |
|-------|-------------|-----------------|--------------------|--------------------|
| planning | yes | yes | yes | yes |
| started | yes | yes | yes | yes |
| finished | no | yes | no | yes |
| cancelled | no | no | no | no |
| archived | no | no | no | no |

### Other Seeded Data

- **12 comments** across entries (from alice, bob, carol, dave, eve, joel)
- **25 reactions** on trips, entries, and comments (all 6 emojis: thumbsup, heart, tada, eyes, fire, rocket)
- **3 checklists**: Japan (all items done), Iceland (partial), Barcelona (mostly empty)
- **3 access requests**: pending, approved, rejected
- **3 invitations**: pending, accepted, expired
- **3 exports**: completed (with file), pending, failed

### Login Helper

```bash
curl -sk -X DELETE https://mail.workeverywhere.docker/messages
agent-browser open https://catalyst.workeverywhere.docker/login && agent-browser wait --load networkidle
agent-browser snapshot -i  # Find email and Login button refs
agent-browser fill @eN "joel@acme.org"
agent-browser click @eM && agent-browser wait --load networkidle
sleep 2
LOGIN_KEY=$(curl -sk https://mail.workeverywhere.docker/messages/1.plain | grep -oP 'key=\K\S+')
agent-browser open "https://catalyst.workeverywhere.docker/email-auth?key=$LOGIN_KEY" && agent-browser wait --load networkidle
agent-browser snapshot -i  # Find Login button
agent-browser click @eN && agent-browser wait --load networkidle
```

### Rails Runner Helper

```bash
cat > /tmp/qa-check.rb <<'RUBY'
# Replace with your check
puts Trip.pluck(:name, :state).inspect
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-check.rb
```

## Prerequisites

- App running in Docker (`bin/cli app start` or `bin/cli app restart`)
- `agent-browser` and `curl` available
- Mail service running (`bin/cli mail start`)
- Seed data loaded (`db:seed` or `db:reset`)

## Step 1: Understand the Feature

Read the GitHub issue and the diff to understand what was built:

```bash
unset GITHUB_TOKEN && gh issue view <ISSUE_NUMBER>
git diff main...HEAD --stat
```

Identify:
- The happy path (what the feature does when everything goes right)
- The inputs (forms, URL params, API calls, events)
- The side effects (emails, DB writes, redirects, events)

## Step 2: Verify the Happy Path

Run through the acceptance criteria using seeded data. Use seeded trips and users rather than creating new records.

**Test across trip states** — every feature that interacts with trips should be tested on at least 3 trips:
1. A **writable** trip (Iceland — started, or Barcelona — planning)
2. A **commentable but not writable** trip (Japan — finished)
3. A **locked** trip (Norway — cancelled, or Patagonia — archived)

**Test across user roles:**
1. **Superadmin** (`joel@acme.org`) — should have full access
2. **Contributor** (`alice@acme.org`) — should have member-level access
3. **Viewer** (`dave@acme.org`) — should have read-only access
4. **Non-member** — use `carol@acme.org` on trips she's not a member of (Japan, Barcelona)

## Step 3: Test Edge Cases

For every input or trigger, test the following:

### Empty / Missing Input
- Submit forms with required fields blank
- Send requests with missing params (use curl directly)
- Test with nil/empty URL params

### Boundary Values
- Text fields at maximum length
- Unicode-only names (e.g., Japanese characters)
- Numbers at 0, negative, extremely large
- Dates in the past, today, far future

### Concurrent / Repeated Actions
- Double-click submit buttons
- Refresh mid-flow
- Duplicate submissions (same email/token used twice)
- Use the seeded rate-limited scenarios: try creating an export when one is already pending

### Unauthorized Access
- Logged-out user accesses protected URL directly
- Non-member accesses trip content by UUID
- Viewer tries to create/edit/delete content
- User A accesses User B's resources

### State-Dependent Behavior (use seeded trips!)
Test the feature on each trip state using the 5 seeded trips:

```bash
# Get trip IDs for testing
cat > /tmp/qa-trips.rb <<'RUBY'
Trip.all.each { |t| puts "#{t.state.ljust(10)} #{t.id} #{t.name}" }
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-trips.rb
```

Then verify the feature behaves correctly on each:
- **planning** (Barcelona) — writable, commentable
- **started** (Iceland) — writable, commentable
- **finished** (Japan) — not writable, commentable
- **cancelled** (Norway) — locked
- **archived** (Patagonia) — locked

### Authorization Matrix Testing
For features with role-based access, test the full matrix:

```
| Action | superadmin | contributor (member) | viewer (member) | non-member |
|--------|-----------|---------------------|-----------------|------------|
| index  | ?         | ?                   | ?               | ?          |
| show   | ?         | ?                   | ?               | ?          |
| create | ?         | ?                   | ?               | ?          |
| edit   | ?         | ?                   | ?               | ?          |
| delete | ?         | ?                   | ?               | ?          |
```

Use seeded users for each role. Log in as different users via the email auth flow.

## Step 4: Verify Side Effects

### Emails
```bash
curl -sk https://mail.workeverywhere.docker/messages \
  | python3 -c "import json,sys; [print(m['id'],m['subject'],m['recipients']) for m in json.load(sys.stdin)]"
```

### Database State
```bash
cat > /tmp/qa-check.rb <<'RUBY'
record = MyModel.last
puts record.attributes.slice("id", "status", "format").inspect
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-check.rb
```

### Redirects & Flash Messages
Verify the user lands on the correct page after each action and sees appropriate feedback.

## Step 5: MCP Server Testing (Mandatory)

The MCP server (`POST /mcp`) is a first-class feature -- test it with the same rigor as the web UI. The server is stateless (no session/handshake needed). Use `tools/call` with `params.name` and `params.arguments`.

### MCP Connection

```bash
MCP_KEY=$(grep MCP_API_KEY .env.development | cut -d= -f2)
MCP_URL="https://catalyst.workeverywhere.docker/mcp"

# Helper function for MCP calls
mcp_call() {
  curl -s "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MCP_KEY" \
    -d "$1"
}
```

### MCP Edge Cases to Test

**Authentication:**
```bash
# No auth header -- expect 401
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Wrong key -- expect 401
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: application/json" \
  -H "Authorization: Bearer wrong-key" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Wrong content type -- expect 415
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: text/plain" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Malformed JSON -- expect -32700 parse error
mcp_call 'not-json-at-all'
```

**Tool invocation:**
```bash
# Unknown tool name -- expect error
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}'

# Wrong JSON-RPC method (common mistake) -- expect "Method not found"
mcp_call '{"jsonrpc":"2.0","id":"1","method":"get_trip_status","params":{}}'

# Missing required arguments
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{}}}'
```

**State guards (test each trip state):**
```bash
# Get all trip IDs
cat > /tmp/qa-trips.rb <<'RUBY'
Trip.all.each { |t| puts "#{t.state.ljust(10)} #{t.id} #{t.name}" }
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-trips.rb

# Create entry on writable trip (started) -- expect success
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"QA Test","entry_date":"2026-03-25","trip_id":"<started-trip-id>"}}}'

# Create entry on finished trip -- expect "not writable"
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"QA Test","entry_date":"2026-03-25","trip_id":"<finished-trip-id>"}}}'

# Create entry on cancelled trip -- expect "not writable"
# Create entry on archived trip -- expect "not writable"

# Comment on finished trip -- expect success (commentable)
# Comment on cancelled trip -- expect "not commentable"
```

**Image upload edge cases:**
```bash
# Upload with invalid base64
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"upload_journal_images","arguments":{"journal_entry_id":"<id>","images":[{"data":"not-valid!!!"}]}}}'
# Expect: "Invalid base64"

# Upload non-image content (HTML disguised as base64)
HTML_B64=$(echo "<html>evil</html>" | base64 -w0)
mcp_call "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"<id>\",\"images\":[{\"data\":\"$HTML_B64\"}]}}}"
# Expect: "Invalid content type"

# Upload > 5 images -- expect "Too many"
# Upload to nonexistent entry -- expect "not found"

# Upload a REAL image and verify it renders in browser
B64_IMG=$(curl -sL "https://picsum.photos/200/150.jpg" | base64 -w0)
mcp_call "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"<id>\",\"images\":[{\"data\":\"$B64_IMG\",\"filename\":\"qa_test.jpg\"}]}}}"
# THEN: open the entry in agent-browser and verify the image renders (not broken)
```

**Cross-verify MCP writes in browser:**
Every MCP write operation must be verified in the web UI. If `create_journal_entry` returns success, open that entry in agent-browser and confirm it renders.

### MCP Report Section

Add to the QA report:

```
## MCP Server

| Test | Expected | Actual |
|------|----------|--------|
| tools/list returns 12 tools | 12 | ? |
| Auth: no key | 401 | ? |
| Auth: wrong key | 401 | ? |
| Auth: wrong content-type | 415 | ? |
| Auth: malformed JSON | -32700 | ? |
| get_trip_status (started) | success with trip data | ? |
| create_journal_entry (started) | success, visible in browser | ? |
| create_journal_entry (finished) | "not writable" error | ? |
| create_comment (finished) | success (commentable) | ? |
| create_comment (cancelled) | "not commentable" error | ? |
| upload_journal_images (valid) | success, image renders in browser | ? |
| upload_journal_images (invalid b64) | "Invalid base64" error | ? |
| upload_journal_images (non-image) | "Invalid content type" error | ? |
| upload_journal_images (> 5 images) | "Too many" error | ? |
| Unknown tool name | error response | ? |
| Wrong JSON-RPC method | "Method not found" | ? |
```

## Step 6: Mobile Testing (Mandatory)

Desktop-passing features frequently break on mobile. Test the full app at mobile viewport width.

### Setup

```bash
agent-browser viewport 393 852  # iPhone 14 Pro
```

### Mobile Test Matrix

Test every page and every interactive element at mobile width. **Do not skip this -- buttons and links that work on desktop are known to break on mobile in this project.**

| Page | Check | How |
|------|-------|-----|
| Home (logged out) | Buttons tappable, no overflow | Screenshot + overflow check |
| Login | Form inputs full-width, submit reachable | Fill + submit |
| Trips index | Cards stack vertically | Screenshot |
| Trip show | All buttons visible and tappable | Tap each button |
| Journal entry | Images scale, reactions tappable, comment form usable | Scroll + interact |
| Checklist | Toggle checkboxes tappable | Tap items |
| Members | Cards stack, roles visible | Screenshot |
| Admin pages | Tables/cards don't overflow | Screenshot + overflow check |

### Overflow Detection

Run on every page:

```bash
agent-browser eval "document.documentElement.scrollWidth > document.documentElement.clientWidth ? 'OVERFLOW: ' + document.documentElement.scrollWidth + 'px > ' + document.documentElement.clientWidth + 'px' : 'OK'"
```

### Touch Target Verification

For every button/link, verify minimum 44x44px touch target:

```bash
agent-browser eval "
  Array.from(document.querySelectorAll('button, a, [role=button], input[type=submit]'))
    .filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && (r.width < 44 || r.height < 44); })
    .map(el => { const r = el.getBoundingClientRect(); return el.textContent.trim().slice(0,30) + ' (' + Math.round(r.width) + 'x' + Math.round(r.height) + ')'; })
"
```

Any element below 44x44 is a mobile usability defect.

### Mobile-Specific Defects

| Symptom | Likely Cause |
|---------|-------------|
| Button ignores taps | Touch target < 44px, z-index overlap, or `pointer-events-none` on parent |
| Link works desktop, not mobile | `hover:` style changing layout, or desktop-only event handler |
| Content overflows | Fixed-width element, `whitespace-nowrap`, or missing `overflow-hidden` |
| Sidebar blocks interaction | Not using `fixed` positioning, or missing backdrop click-to-close |
| Form zooms on focus (iOS) | Input font-size < 16px |

### Mobile Report Section

```
## Mobile (393x852)

| Page | Overflow | Buttons Work | Touch Targets OK | Notes |
|------|----------|-------------|------------------|-------|
| Home (logged out) | ? | ? | ? | |
| Login | ? | ? | ? | |
| Trips index | ? | ? | ? | |
| Trip show | ? | ? | ? | |
| Journal entry | ? | ? | ? | |
| Checklist | ? | ? | ? | |
| Members | ? | ? | ? | |
| Users | ? | ? | ? | |
| Access requests | ? | ? | ? | |
| Invitations | ? | ? | ? | |
```

## Step 7: Regression Check

Test the features most likely broken by this change. Use seeded data for efficiency:

- **Trip CRUD**: View/edit a seeded trip (Japan or Barcelona)
- **Journal entries**: View a seeded entry with images, comments, reactions
- **Authentication**: Log in/out via email auth using a seeded user
- **Comments & reactions**: Verify existing seeded comments/reactions render
- **Checklists**: Verify seeded checklist items render with correct completion state
- **Members**: Verify seeded memberships display correctly
- **MCP Server**: tools/list returns 12 tools, get_trip_status returns data

## Step 8: Run Automated Tests

```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

## Output Format

Write the report to `prompts/Phase N - QA Review.md`:

```markdown
# QA Review -- <branch name>

**Branch:** `<branch>`
**Phase:** N
**Date:** YYYY-MM-DD
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Full test suite:** N examples, 0 failures, N pending
- **Linting:** N files, no offenses

---

## Acceptance Criteria

- [x] <criterion> -- PASS
- [ ] <criterion> -- FAIL: <details>

---

## Defects (must fix before merge)

### D1: <title>
**File:** `path:line`
**Steps to reproduce:** ...
**Expected:** ...
**Actual:** ...
**Recommended fix:** ...

---

## Edge Case Gaps (should fix or document)

### E1: <title>
**Risk if left unfixed:** ...
**Recommendation:** ...

---

## Observations

- <notable findings that aren't defects>

---

## Regression Check

- **Trip CRUD** -- PASS/FAIL
- **Journal entries** -- PASS/FAIL
- **Authentication** -- PASS/FAIL
- **Comments & reactions** -- PASS/FAIL
- **MCP Server** -- PASS/FAIL

## MCP Server

| Test | Expected | Actual |
|------|----------|--------|
| tools/list | 12 tools | ? |
| Auth: no key | 401 | ? |
| get_trip_status | success | ? |
| create_journal_entry (writable) | success + visible in UI | ? |
| create_journal_entry (locked) | "not writable" | ? |
| upload_journal_images (valid) | success + renders in UI | ? |
| upload_journal_images (bad b64) | "Invalid base64" | ? |
| upload_journal_images (non-image) | "Invalid content type" | ? |

## Mobile (393x852)

| Page | Overflow | Buttons | Touch Targets | Notes |
|------|----------|---------|---------------|-------|
| Home | ? | ? | ? | |
| Login | ? | ? | ? | |
| Trips | ? | ? | ? | |
| Trip show | ? | ? | ? | |
| Entry | ? | ? | ? | |
| Checklist | ? | ? | ? | |
```

## Fixing Defects

For each Defect, open a fix before the PR is merged. Follow github-workflow commit conventions. Add a regression spec if the defect is logic-based.

For Edge Case Gaps, ask the user: fix now or create a follow-up issue?
