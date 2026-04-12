# Phase 15 — Feed Wall Implementation Steps

## Execution Date: 2026-04-12

### Context
- GitHub Issue: joel/trip#94
- Pull Request: joel/trip#95
- Branch: `feature/phase-15-feed-wall`
- Google Stitch Project: `projects/3314239195447065678`

### Design Retrieved from Google Stitch MCP
5 screens fetched and reviewed:
1. **Journal Feed** (Mobile) — chronological card feed with FAB
2. **Trip Feed (Mobile)** — category-tagged cards
3. **Trip Show - Collapsed Feed (Desktop)** — sidebar + feed wall
4. **Trip Show - Expanded Entry (Desktop)** — inline expansion with gallery, reactions, comments
5. **Trip Feed - Empty State** — empty CTA with quick-start buttons

### Steps Taken

#### Step 1: GitHub Issue & Kanban (Task 1)
- Created issue #94 on joel/trip with label `enhancement`
- Added to Kanban project, moved to In Progress
- Assigned to joel
- Created branch `feature/phase-15-feed-wall`

#### Step 2: Model Scope (Task 2)
- **File:** `app/models/journal_entry.rb`
- Added `scope :reverse_chronological` ordering by `entry_date: :desc, created_at: :desc, id: :desc`
- Added model spec in `spec/models/journal_entry_spec.rb`

#### Step 3: Trips Controller (Task 3)
- **File:** `app/controllers/trips_controller.rb`
- Changed `show` to use `reverse_chronological` with expanded eager loads:
  `:author, :reactions, comments: :user, images_attachments: :blob, journal_entry_subscriptions: :user`

#### Step 4: Auto-Subscribe Trip Members (Task 4)
- **File:** `app/actions/journal_entries/create.rb`
- Replaced `subscribe_author` with `subscribe_trip_members`
- Uses `find_or_create_by!` per member (UUID-safe, idempotent)
- Initially tried `insert_all` but SQLite UUID PKs require explicit IDs; switched to individual creates

#### Step 5: Remove Show Route & View (Task 5)
- **File:** `config/routes.rb` — changed `except: [:index]` to `except: %i[index show]`
- **File:** `app/controllers/journal_entries_controller.rb` — removed `show` action, updated `set_journal_entry` filter
- **Deleted:** `app/views/journal_entries/show.rb`

#### Step 6: Redirect CRUD to Feed (Task 6)
- **Files:** `journal_entries_controller.rb`, `comments_controller.rb`, `reactions_controller.rb`
- All redirects now use `trip_path(@trip, anchor: dom_id(@entry))` instead of `[@trip, @entry]`
- Added `include ActionView::RecordIdentifier` to `JournalEntriesController`

#### Step 7: Expandable Feed Card (Task 7)
- **File:** `app/components/journal_entry_card.rb` — rewritten as expandable feed item
  - Header with date, title, location, author, mute toggle, edit link
  - Image preview (collapsed), full image grid (expanded)
  - Description line-clamped when collapsed, full when expanded
  - Expandable body contains: prose, images, reactions, comments, comment form, delete button
  - Footer with reaction count, comment count, "Read more" toggle
  - Preserves Turbo Stream DOM IDs: `comments_<id>`, `reaction_summary_<id>`, `comment_form_<id>`
- **File:** `app/javascript/controllers/feed_entry_controller.js` — Stimulus controller
  - Static targets: body, label
  - `toggle()` action flips hidden state and button text
- **File:** `app/views/trips/show.rb` — updated feed header ("JOURNAL FEED" / "The story so far"), enhanced empty state

#### Step 8: Mute Toggle (Task 8)
- **File:** `app/components/journal_entry_follow_button.rb` — reworked from text buttons to bell icon toggle
  - Subscribed state: filled bell icon in primary color, tooltip "Notifications on — click to mute"
  - Muted state: bell-off icon in muted color, tooltip "Notifications off — click to resume"
  - Wrapped in `div#journal_entry_<id>_mute` for Turbo Stream replacement
- **New file:** `app/components/icons/bell_off.rb` — bell with diagonal slash line
- **File:** `app/controllers/journal_entry_subscriptions_controller.rb`
  - Added `include TurboStreamable`
  - `create`/`destroy` now respond to turbo_stream format with `stream_replace` of mute button
  - HTML fallback redirects to trip page with anchor

#### Step 9: Spec Updates (Tasks 9-10)
- **File:** `spec/requests/journal_entries_spec.rb` — removed show test, added auto-subscribe and redirect assertions
- **File:** `spec/requests/journal_entry_subscriptions_spec.rb` — updated redirect expectations, added turbo_stream response assertions
- **File:** `spec/requests/comments_spec.rb` — updated redirect to trip page anchor
- **File:** `spec/system/journal_entries_spec.rb` — rewritten for feed wall (create, ordering, expand, edit, delete)
- **File:** `spec/system/comments_spec.rb` — updated to visit trip page and expand card
- **File:** `spec/system/notifications_spec.rb` — replaced follow/unfollow tests with mute toggle assertion

#### Step 10: Lint & Tests (Task 11)
- RuboCop: 16 files inspected, 0 offenses (after auto-fix and manual fixes)
- RSpec (non-system): 572 examples, 0 failures
- Fixes applied during lint:
  - `insert_all` → `find_or_create_by!` (UUID PK compatibility)
  - `ClassLength` — condensed card component by inlining short methods
  - `SymbolProc` — auto-corrected `entries.map { |e| e.text }` → `entries.map(&:text)`
  - `NegationMatcher` — auto-corrected `not_to have_content` → `have_no_content`

#### Step 11: Commits & PR (Task 13)
- 9 atomic commits, each passing RuboCop pre-commit hook
- Pushed to `origin/feature/phase-15-feed-wall`
- Created PR #95 with full description
- Moved issue #94 to "In Review" on Kanban

### Pending
- [ ] Runtime verification (Task 12) — requires Docker rebuild (`bin/cli app rebuild`)
- [ ] System tests — requires running Capybara with headless Chrome in Docker

### Risks Encountered
1. **OOM crashes** — `mise x --` combined with shell snapshots caused fork bombs (1993+ rubocop processes). Workaround: use `PATH` directly instead of `mise x --`
2. **UUID primary keys** — `insert_all` doesn't auto-generate UUIDs in SQLite; switched to `find_or_create_by!`
3. **Missing `updated_at` column** — `journal_entry_subscriptions` table lacks `updated_at`; removed from insert hash
