# Phase 4: Authorization & Policy Enforcement - Steps Taken

**Date:** 2026-03-22
**Issue:** https://github.com/joel/trip/issues/16
**PR:** https://github.com/joel/trip/pull/17
**Branch:** `feature/phase4-authorization`
**Commit:** `860a73f`

---

## Step 1: Create GitHub Issue

Created issue #16 on [joel/trip](https://github.com/joel/trip/issues/16) with:
- Title: "Phase 4: Authorization & Policy Enforcement"
- Label: `enhancement`
- Body: Full summary, scope, permission matrix, and verification criteria

**Command:**
```bash
unset GITHUB_TOKEN && gh issue create --repo joel/trip --title "Phase 4: Authorization & Policy Enforcement" --label "enhancement" --body "..."
```

**Note:** Kanban board update was blocked — `gh` CLI missing `read:project` scope. Requires interactive `gh auth refresh -s read:project,project -h github.com`.

---

## Step 2: Create Feature Branch

```bash
git checkout main && git pull origin main
git checkout -b feature/phase4-authorization
```

---

## Step 3: Create 3 Policy Files

### 3a. `app/policies/trip_policy.rb`

New file. Permission matrix:
- `index?` — any authenticated user
- `show?` — superadmin or trip member
- `create?`, `destroy?`, `transition?` — superadmin only
- `edit?`, `update?` — superadmin or contributor

Private helpers: `trip_membership`, `member?`, `contributor?` — query `trip_memberships.find_by(user:)`.

### 3b. `app/policies/journal_entry_policy.rb`

New file. Permission matrix:
- `show?` — superadmin or trip member
- `create?` — superadmin or (contributor AND trip is writable)
- `edit?`, `update?`, `destroy?` — superadmin or (contributor AND own entry)

Private helpers: `trip_membership`, `member?`, `contributor?`, `own_entry?` (checks `record.author_id == user.id`).

### 3c. `app/policies/trip_membership_policy.rb`

New file. Permission matrix:
- `index?` — superadmin or trip member
- `create?`, `destroy?` — superadmin only

Private helper: `member_of_trip?` — uses `trip_memberships.exists?(user:)`.

---

## Step 4: Add authorize! to 3 Controllers

### 4a. `app/controllers/trips_controller.rb`

- Added `before_action :authorize_trip!` after existing before_actions
- Added private method `authorize_trip!` calling `authorize!(@trip || Trip)`

### 4b. `app/controllers/journal_entries_controller.rb`

- Added `before_action :authorize_journal_entry!` after existing before_actions
- Added private method `authorize_journal_entry!` calling `authorize!(@journal_entry || @trip.journal_entries.new)`
- The transient `@trip.journal_entries.new` record allows `create?` to check `record.trip.writable?`

### 4c. `app/controllers/trip_memberships_controller.rb`

- Added `before_action :set_membership, only: [:destroy]` (extracted from inline `destroy` logic)
- Added `before_action :authorize_membership!`
- Added private methods `set_membership` and `authorize_membership!`
- Updated `destroy` action to use `@membership` instance variable instead of local variable

---

## Step 5: Update 7 Views/Components with allowed_to? Guards

### 5a. `app/views/trips/index.rb` (line 19)

- Changed `current_user&.role?(:superadmin)` to `allowed_to?(:create?, Trip)` for "New trip" button

### 5b. `app/views/trips/show.rb`

- Wrapped "Edit" link with `allowed_to?(:edit?, @trip)`
- Wrapped "Delete" button with `allowed_to?(:destroy?, @trip)`
- "Members" link remains always visible (any member can see who's on the trip)
- Added early return `allowed_to?(:transition?, @trip)` to `render_state_transitions`
- Changed "New entry" guard from `@trip.writable?` to `allowed_to?(:create?, @trip.journal_entries.new)`

### 5c. `app/views/journal_entries/show.rb`

- Wrapped "Edit" link with `allowed_to?(:edit?, @entry)`
- Wrapped "Delete" button with `allowed_to?(:destroy?, @entry)`
- "Back to trip" link remains always visible

### 5d. `app/components/trip_card.rb`

- Wrapped "Edit" link with `allowed_to?(:edit?, @trip)`
- "View" link remains always visible

### 5e. `app/components/journal_entry_card.rb`

- Wrapped "Edit" link with `allowed_to?(:edit?, @entry)`
- "View" link remains always visible

### 5f. `app/views/trip_memberships/index.rb`

- Wrapped "Add member" link with `allowed_to?(:create?, @trip.trip_memberships.new)`

### 5g. `app/components/trip_membership_card.rb`

- Added early return `allowed_to?(:destroy?, @membership)` to `render_actions`
- Entire "Remove" button div is hidden for non-superadmin users

---

## Step 6: Create 3 Policy Specs

### 6a. `spec/policies/trip_policy_spec.rb`

11 examples covering:
- `index?` — any authenticated user allowed
- `show?` — superadmin, contributor, viewer allowed; outsider denied
- `create?` — superadmin allowed; contributor, outsider denied
- `edit?` — superadmin, contributor allowed; viewer, outsider denied
- `destroy?` — superadmin allowed; contributor denied
- `transition?` — superadmin allowed; contributor denied

### 6b. `spec/policies/journal_entry_policy_spec.rb`

12 examples covering:
- `show?` — superadmin, member allowed; outsider denied
- `create?` — superadmin allowed; contributor on writable trip allowed; contributor on finished trip denied; viewer denied
- `edit?` — superadmin, author allowed; other contributor denied; viewer denied
- `destroy?` — superadmin, author allowed; other contributor denied

### 6c. `spec/policies/trip_membership_policy_spec.rb`

6 examples covering:
- `index?` — superadmin, member allowed; outsider denied
- `create?` — superadmin allowed; member denied
- `destroy?` — superadmin allowed; member denied

---

## Step 7: Add Authorization Tests to Request Specs

### 7a. `spec/requests/trips_spec.rb`

Added `describe "authorization"` block with:
- `when logged in as viewer` — allows show, forbids edit/create/destroy/transition (all 403)
- `when logged in as non-member` — forbids show (403)

### 7b. `spec/requests/journal_entries_spec.rb`

Added `describe "authorization"` block with:
- `when logged in as viewer` — allows show, forbids create (403)
- `when logged in as other contributor (not author)` — forbids edit of another's entry (403)

### 7c. `spec/requests/trip_memberships_spec.rb`

Added `describe "authorization"` block with:
- Contributor can access index (200)
- Contributor forbidden from create and destroy (403)

---

## Step 8: Pre-Commit Validation

### Lint

```bash
mise x -- bundle exec rake project:fix-lint   # 0 offenses, no autocorrections needed
mise x -- bundle exec rake project:lint        # 247 files inspected, 0 offenses
```

### Tests

```bash
mise x -- bundle exec rake project:tests         # 214 examples, 0 failures, 2 pending
mise x -- bundle exec rake project:system-tests  # 13 examples, 0 failures
```

---

## Step 9: Commit

### First attempt — failed

RuboCop `RSpec/ContextWording` cop rejected context descriptions like `"as viewer"`. Must start with `when`, `with`, or `without`.

**Fix:** Changed all context descriptions:
- `"as viewer"` -> `"when logged in as viewer"`
- `"as non-member"` -> `"when logged in as non-member"`
- `"as other contributor (not author)"` -> `"when logged in as other contributor (not author)"`

### Second attempt — passed

```bash
git add <19 specific files>
git commit -m "feat: Add authorization policies for Trip, JournalEntry, TripMembership ..."
```

Overcommit results:
- Pre-commit: TrailingWhitespace OK, FixMe OK, RuboCop OK
- Commit-msg: TextWidth WARNING (body lines >72 chars), CapitalizedSubject WARNING (`feat:` prefix), TrailingPeriod OK

Commit: `860a73f`

---

## Step 10: Push and Create PR

```bash
unset GITHUB_TOKEN && git push -u origin feature/phase4-authorization
unset GITHUB_TOKEN && gh pr create --repo joel/trip --title "Phase 4: Authorization & Policy Enforcement" --body "..."
```

**PR:** https://github.com/joel/trip/pull/17

---

## Step 11: Kanban Board Update

**Blocked:** `gh` CLI missing `read:project` scope. Requires interactive:
```bash
gh auth refresh -s read:project,project -h github.com
```

Once authorized, move issue through: Backlog -> Ready -> In Progress -> In Review.

---

## Step 12: Runtime Test

**Pending.** To be executed with `/product-review` skill after Kanban auth is resolved.

---

## Summary of Changes

| Category | Files | Count |
|----------|-------|-------|
| New policies | `app/policies/trip_policy.rb`, `journal_entry_policy.rb`, `trip_membership_policy.rb` | 3 |
| Modified controllers | `trips_controller.rb`, `journal_entries_controller.rb`, `trip_memberships_controller.rb` | 3 |
| Modified views | `trips/index.rb`, `trips/show.rb`, `journal_entries/show.rb`, `trip_memberships/index.rb` | 4 |
| Modified components | `trip_card.rb`, `journal_entry_card.rb`, `trip_membership_card.rb` | 3 |
| New policy specs | `spec/policies/trip_policy_spec.rb`, `journal_entry_policy_spec.rb`, `trip_membership_policy_spec.rb` | 3 |
| Modified request specs | `spec/requests/trips_spec.rb`, `journal_entries_spec.rb`, `trip_memberships_spec.rb` | 3 |
| **Total** | | **19 files** |

### Test Results

| Suite | Examples | Failures | Pending |
|-------|----------|----------|---------|
| Unit + Request specs | 214 | 0 | 2 |
| System specs | 13 | 0 | 0 |
| RuboCop | 247 files | 0 offenses | - |

### Key Design Decisions

1. **Trip membership lookup in policies** — One DB query per auth check via `find_by(user:)`. Simple and correct.
2. **Contributor can only edit own entries** — `own_entry?` checks `record.author_id == user.id`.
3. **Writable guard in JournalEntryPolicy#create?** — Prevents entry creation on finished/archived trips.
4. **No ActionPolicy scopes** — Manual Trip scoping in `TripsController#index` kept as-is.
5. **Members link always visible** — Any user who can see the trip can see who's on it.
6. **authorize! on class for index/new/create** — Transient records (`@trip.entries.new`) for policy checks.
