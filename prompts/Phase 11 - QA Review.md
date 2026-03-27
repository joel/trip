# QA Review -- feature/phase-11-notification-center

**Branch:** `feature/phase-11-notification-center`
**Phase:** 11
**Date:** 2026-03-27
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Unit/request tests:** 519 examples, 0 failures, 2 pending
- **System tests:** 22 examples, 0 failures
- **Linting:** 403 files inspected, no offenses detected (RuboCop + ERB Lint)
- **Bullet N+1 detection:** Enabled with `raise: true` in test environment -- no violations raised

---

## Acceptance Criteria

- [x] Notification model with polymorphic notifiable, recipient, actor, event_type enum, read_at -- PASS
- [x] JournalEntrySubscription model with unique constraint and auto-subscribe on create/comment -- PASS
- [x] NotifyEntryCreatedJob fans out to all trip members except the author -- PASS
- [x] NotifyCommentAddedJob fans out to all entry subscribers except the commenter -- PASS
- [x] CreateNotificationJob is idempotent (unique index + rescue RecordNotUnique) -- PASS
- [x] NotificationMailer sends entry_created and comment_added emails -- PASS
- [x] NotificationSubscriber dispatches jobs on journal_entry.created and comment.created events -- PASS
- [x] TripMembershipSubscriber dispatches member_added notification on trip_membership.created -- PASS
- [x] Action Cable NotificationsChannel streams to per-user channel -- PASS
- [x] Stimulus notification_badge_controller updates badge in real-time -- PASS
- [x] Bell icon with unread count badge in desktop sidebar -- PASS
- [x] Notifications index page with grouped-by-date display -- PASS
- [x] Mark individual notification as read -- PASS
- [x] Mark all notifications as read -- PASS
- [x] NotificationPolicy scopes notifications to the recipient -- PASS
- [ ] Follow/unfollow button on journal entry show page -- FAIL (see D1)
- [x] Actor_id added to event payloads for journal_entry.created, comment.created, trip_membership.created -- PASS
- [x] User deletion cascades actor-side notifications (acted_notifications dependent: destroy) -- PASS
- [x] Mobile bottom nav includes notification link -- PASS (but no badge, see E2)

---

## Defects (must fix before merge)

### D1: Subscription authorization uses wrong policy rule -- viewers and finished-trip members cannot follow entries

**File:** `app/controllers/journal_entry_subscriptions_controller.rb:37-39`

**Steps to reproduce:**
1. Log in as `dave@acme.org` (viewer on Japan trip)
2. Navigate to any journal entry on the Japan trip
3. Click "Follow" button
4. Receive 403 Forbidden

OR:
1. Log in as `alice@acme.org` (contributor on Japan trip, which is finished)
2. Navigate to any journal entry on Japan trip
3. Click "Follow" button
4. Receive 403 Forbidden (because finished trips are not writable)

**Expected:** Viewers and members on finished/commentable trips should be able to follow/unfollow journal entries. Following is a read-like subscription preference, not a write operation.

**Actual:** The `authorize_entry!` method calls `authorize!(@journal_entry, with: JournalEntryPolicy)` without specifying `to:`, so ActionPolicy defaults to `"#{action_name}?"` -- meaning `create?` for the create action and `destroy?` for the destroy action. `JournalEntryPolicy#create?` requires `(superadmin? || contributor?) && record.trip.writable?`, which blocks viewers and members on non-writable trips.

**Recommended fix:**
```ruby
def authorize_entry!
  authorize!(@journal_entry, with: JournalEntryPolicy, to: :show?)
end
```

This uses `show?` which only requires `superadmin? || member?`, which is the correct gate for follow/unfollow. Also add a guard in `render_follow_button` in `app/views/journal_entries/show.rb` to hide the button for non-members (defense in depth).

**Test gap:** The subscription request spec (`spec/requests/journal_entry_subscriptions_spec.rb:61-68`) only tests with a contributor role on a writable trip (both are factory defaults). Add tests for:
- Viewer member can subscribe (currently fails)
- Member on a finished trip can subscribe (currently fails)

---

## Edge Case Gaps (should fix or document)

### E1: No pagination on notifications index

**File:** `app/controllers/notifications_controller.rb:9`

**Risk if left unfixed:** A user with hundreds of notifications will load all of them in a single page. This causes slow page loads, high memory usage, and poor UX. The `recent` scope orders by `created_at DESC` with no limit.

**Recommendation:** Add pagination (e.g., `.limit(50)` or use a pagination gem like Pagy) or implement infinite scroll. At minimum, add `.limit(100)` as a safety cap.

### E2: Mobile bottom nav shows no unread notification count badge

**File:** `app/components/mobile_bottom_nav.rb:20-21`

**Risk if left unfixed:** Mobile users have no visual indicator of unread notifications. The desktop sidebar uses the `NotificationBell` component with a badge and Stimulus controller for real-time updates, but the mobile nav uses a plain `nav_tab` link.

**Recommendation:** Either use the `NotificationBell` component in mobile nav (adapted for mobile layout), or add a badge span to the mobile "Alerts" nav_tab that mirrors the desktop behavior. The notification_badge Stimulus controller should also be wired to the mobile badge.

### E3: Missing `includes(:notifiable)` on notifications index causes N+1 on polymorphic associations

**File:** `app/controllers/notifications_controller.rb:9-10`

**Current query:**
```ruby
current_user.notifications.recent.includes(:actor)
```

**Risk if left unfixed:** The `NotificationCard#target_path` method accesses `@notification.notifiable` for every notification, then chains through `.trip` or `.journal_entry.trip`. With 20 notifications, this produces up to 20 individual SELECT queries for notifiable records plus 20 more for their trip associations. Bullet doesn't catch this in tests because the system spec only creates one notification.

**Recommendation:** Add polymorphic includes:
```ruby
current_user.notifications.recent
            .includes(:actor, notifiable: [])
```
Rails handles polymorphic includes by grouping queries per type (at most 3 extra queries for 3 types). For nested associations (`Comment -> journal_entry -> trip`), consider adding an eager-load scope or caching the trip_id on the notification itself for link generation.

### E4: Orphaned notifications when notifiable records are deleted

**File:** `app/models/notification.rb:4`

**Risk if left unfixed:** Deleting a trip cascades through journal_entries -> comments -> reactions, but notifications pointing to those records become orphans (`notifiable_id` references a non-existent record). The `NotificationCard#target_path` handles this gracefully (returns nil), but the notification still renders with text like "created a new journal entry" linking to nothing.

**Recommendation:** Either:
1. Add `has_many :notifications, as: :notifiable, dependent: :destroy` to JournalEntry, Comment, and TripMembership models, or
2. Add a cleanup job that periodically removes orphaned notifications, or
3. Document this as acceptable (notifications fade over time and orphans are harmless).

### E5: Race condition on find_or_create_by! in subscription controller

**File:** `app/controllers/journal_entry_subscriptions_controller.rb:10-12`

**Risk if left unfixed:** If a user double-clicks the Follow button rapidly, the second request might hit a `RecordNotUnique` exception from the unique index before `find_or_create_by!` can find the existing record. This is extremely unlikely with normal usage.

**Recommendation:** Wrap in a rescue:
```ruby
def create
  @journal_entry.journal_entry_subscriptions.find_or_create_by!(user: current_user)
  redirect_to [@trip, @journal_entry], notice: "You are now following this entry."
rescue ActiveRecord::RecordNotUnique
  redirect_to [@trip, @journal_entry], notice: "You are now following this entry."
end
```

---

## Observations

- **Memoized unread count query on every page:** `unread_notification_count` in ApplicationController runs a COUNT query on every page load for authenticated users (via the sidebar bell). This is acceptable for now but could be cached in the session or via a counter_cache if performance becomes a concern at scale.

- **Actor deletion cascades notifications:** When a user (actor) is deleted, all notifications where they were the actor are destroyed (`acted_notifications` with `dependent: :destroy`). This is tested and intentional, but recipients lose those notifications. An alternative would be `dependent: :nullify` with an optional actor, showing "Someone" in the UI (which the card already handles with `return "Someone" unless @notification.actor`).

- **Solid test coverage for new code:** The phase adds 8 new spec files covering models, jobs, request specs, and system specs. All job specs test the happy path, idempotency, and not-found edge cases. The action specs test auto-subscription and duplicate prevention.

- **Clean event architecture:** The subscriber pattern is well-structured -- NotificationSubscriber handles journal_entry.created and comment.created events, while TripMembershipSubscriber handles member_added. The event filter in the initializer is precise.

- **Idempotent job design:** CreateNotificationJob uses a database unique index (`idx_notifications_uniqueness`) and rescues `RecordNotUnique` for safe retries. This is the correct pattern for job idempotency.

- **ActionCable channel properly authenticated:** The connection uses `request.session[:account_id]` from Rodauth and calls `reject_unauthorized_connection` if not found. The channel streams to a per-user topic `"notifications:user_#{current_user.id}"`.

---

## Regression Check

- **Trip CRUD** -- PASS (no changes to trip models/controllers)
- **Journal entries** -- PASS (only additions: `has_many :journal_entry_subscriptions` and follow button in show view)
- **Authentication** -- PASS (no changes to Rodauth config; ActionCable connection correctly reads session)
- **Comments & reactions** -- PASS (Comments::Create action adds subscription step but existing behavior preserved)
- **Checklists** -- PASS (no changes)
- **Members** -- PASS (TripMemberships::Assign adds actor parameter, controller already passes current_user)
- **MCP Server** -- PASS (not modified in this branch; MCP tools operate independently of notification system)

---

## MCP Server

No MCP-related changes in this phase. The MCP server was not modified and continues to operate independently. MCP-triggered writes (via Jack system actor) will emit events through the existing subscriber system, which now also dispatches notifications. This is correct behavior -- MCP journal entry creates and comments will trigger notifications to trip members.

| Test | Expected | Actual |
|------|----------|--------|
| tools/list returns tools | 12 tools | Not re-tested (no MCP changes) |
| MCP writes trigger notifications | Events dispatched | Verified by code review (actions emit events, subscribers dispatch jobs) |

---

## Mobile (393x852)

Mobile-specific testing was conducted via code review (no live Docker environment available in this session).

| Page | Overflow | Buttons | Touch Targets | Notes |
|------|----------|---------|---------------|-------|
| Notifications index | OK (code review) | OK | OK | Standard ha-card components |
| Journal entry (follow button) | OK | OK | OK | ha-button class provides adequate sizing |
| Sidebar bell | N/A | N/A | N/A | Sidebar hidden on mobile (md:flex) |
| Mobile bottom nav | OK | OK | Potential issue | "Alerts" tab has no badge (see E2) |

---

## Summary

Phase 11 is well-implemented with clean architecture, good test coverage (519 unit + 22 system tests, all passing), and proper idempotency patterns. The main defect (D1) is an authorization rule mismatch that blocks viewers and finished-trip members from following journal entries -- this is a functional bug that should be fixed before merge. The edge case gaps (E1-E5) range from important (pagination, mobile badge) to low-priority (orphaned notifications, race conditions) and can be addressed in follow-up work.
