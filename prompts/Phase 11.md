# Phase 11: Notification Center

## Context

Phases 1-10 are complete. The app has a full event system (Rails.event with 10 subscribers, 10 jobs, 7 mailers) but no in-app notifications. Users only learn about activity through email. The Telegram bot (Jack) creates journal entries and comments in production, but trip members have no way to know this happened without manually checking the app.

**Goal:** Add an in-app Notification Center with email notifications for key events, Action Cable real-time badge updates, and an unfollow mechanism for journal entries.

**Push notifications (Web Push API, VAPID keys)** are deferred to a future phase.

**Issue:** To be created on GitHub (joel/trip)

---

## Notification Rules

| Event | Notify? | Recipients | Exclude |
|-------|---------|------------|---------|
| User added to trip | Yes | The added user | - |
| Journal entry created | Yes | All trip members | Author |
| Comment added | Yes | All subscribed users for that entry | Commenter |
| Journal entry updated | No | - | - |
| Journal entry deleted | No | - | - |

Users can **unfollow** a journal entry to stop receiving comment notifications.

**Auto-subscribe:** When a user creates a journal entry or comments on one, they are automatically subscribed to that entry's comment notifications.

---

## Scope

### 1. Notification Model

- **Table:** `notifications` with UUID PK
- **Polymorphic:** `notifiable_type` + `notifiable_id` (TripMembership, JournalEntry, Comment)
- **Recipient:** `recipient_id` FK(users) — who receives the notification
- **Actor:** `actor_id` FK(users) — who triggered it (for "Alice added an entry...")
- **Event type:** integer enum `{ member_added: 0, entry_created: 1, comment_added: 2 }`
- **Read state:** `read_at` datetime (null = unread)
- **Scopes:** `unread`, `recent`
- **Methods:** `read?`, `mark_as_read!`

### 2. JournalEntrySubscription Model

- **Table:** `journal_entry_subscriptions` with UUID PK
- **Fields:** `user_id`, `journal_entry_id`, `created_at`
- **Unique:** `(user_id, journal_entry_id)`
- **Purpose:** Track who is "following" a journal entry for comment notifications
- **Auto-subscribe:** On journal entry creation (author) and comment creation (commenter)
- **Unfollow:** User clicks "Unfollow" button on journal entry page

### 3. Notification Jobs

- **`CreateNotificationJob`** — Creates a single Notification record and broadcasts unread count via Action Cable
- **`NotifyEntryCreatedJob`** — Fan-out: for each trip member (except author), creates notification + sends email
- **`NotifyCommentAddedJob`** — Fan-out: for each entry subscriber (except commenter), creates notification + sends email

### 4. NotificationMailer

- `entry_created(journal_entry_id, recipient_id)` — "New entry in {trip}: {entry name}"
- `comment_added(comment_id, recipient_id)` — "New comment on {entry} in {trip}"

### 5. NotificationSubscriber

- Listens for `journal_entry.created` → dispatches `NotifyEntryCreatedJob`
- Listens for `comment.created` → dispatches `NotifyCommentAddedJob`
- `TripMembershipSubscriber` updated to also dispatch `CreateNotificationJob` for member_added

### 6. Action Cable Channel

- `NotificationsChannel` — streams to `notifications:user_{id}`
- `CreateNotificationJob` broadcasts `{ unread_count: N }` after creating a notification
- Stimulus controller on sidebar bell icon updates badge count in real-time
- Connection authenticated via Rodauth session (`request.session["account_id"]`)

### 7. Notification Bell UI

- Bell icon NavItem in sidebar (after "Trips", before "Users")
- Unread count badge (red dot with number, hidden when 0)
- Clicking navigates to `/notifications` index page
- `unread_notification_count` helper in `ApplicationController`

### 8. Notifications Index Page

- Lists notifications grouped by date, most recent first
- Each notification card shows: actor name, action description, time ago, read/unread state
- Click navigates to the relevant resource (trip, entry, comment)
- "Mark as read" per notification
- "Mark all as read" bulk action

### 9. Follow/Unfollow UI

- Button on journal entry show page
- "Following" (when subscribed) → click to unfollow
- "Follow" (when not subscribed) → click to follow
- Uses standard `button_to` with POST/DELETE

---

## Files to Create (~25)

| File | Purpose |
|------|---------|
| `db/migrate/..._create_notifications.rb` | Notifications table |
| `db/migrate/..._create_journal_entry_subscriptions.rb` | Subscriptions table |
| `app/models/notification.rb` | Notification model |
| `app/models/journal_entry_subscription.rb` | Subscription model |
| `app/jobs/create_notification_job.rb` | Create single notification + broadcast |
| `app/jobs/notify_entry_created_job.rb` | Fan-out to trip members |
| `app/jobs/notify_comment_added_job.rb` | Fan-out to subscribers |
| `app/mailers/notification_mailer.rb` | Email notifications |
| `app/views/notification_mailer/entry_created.text.erb` | Email template |
| `app/views/notification_mailer/comment_added.text.erb` | Email template |
| `app/subscribers/notification_subscriber.rb` | Event subscriber |
| `app/channels/application_cable/connection.rb` | Cable auth |
| `app/channels/application_cable/channel.rb` | Base channel |
| `app/channels/notifications_channel.rb` | Notifications channel |
| `app/javascript/controllers/notification_badge_controller.js` | Badge Stimulus controller |
| `app/components/icons/bell.rb` | Bell SVG icon |
| `app/components/notification_card.rb` | Notification display card |
| `app/components/journal_entry_follow_button.rb` | Follow/unfollow button |
| `app/views/notifications/index.rb` | Notifications page |
| `app/controllers/notifications_controller.rb` | CRUD for notifications |
| `app/controllers/journal_entry_subscriptions_controller.rb` | Follow/unfollow |
| `app/policies/notification_policy.rb` | Authorization |
| `spec/factories/notifications.rb` | Test factory |
| `spec/factories/journal_entry_subscriptions.rb` | Test factory |

## Files to Modify (~11)

| File | Change |
|------|--------|
| `app/models/user.rb` | Add `has_many :notifications`, `has_many :journal_entry_subscriptions` |
| `app/models/journal_entry.rb` | Add `has_many :journal_entry_subscriptions`, `has_many :subscribers` |
| `app/actions/trip_memberships/assign.rb` | Add `actor_id` to event payload |
| `app/controllers/trip_memberships_controller.rb` | Pass `current_user:` to action |
| `app/subscribers/trip_membership_subscriber.rb` | Add CreateNotificationJob dispatch |
| `config/initializers/event_subscribers.rb` | Register NotificationSubscriber |
| `config/routes.rb` | Notification + subscription routes |
| `config/importmap.rb` | Pin `@rails/actioncable` |
| `app/components/sidebar.rb` | Add bell icon NavItem with badge |
| `app/controllers/application_controller.rb` | `unread_notification_count` helper |
| `app/views/journal_entries/show.rb` | Follow/unfollow button |

---

## Key Design Decisions

1. **Polymorphic `notifiable`** — Same pattern as Reaction's `reactable`. The notification record points to the thing that was created (TripMembership, JournalEntry, Comment), carrying all context without JSON metadata.

2. **Separate subscription table** — `JournalEntrySubscription` is a simple join table. YAGNI over a generic preferences system. Maps directly to the "unfollow a journal entry" requirement.

3. **Action Cable for real-time** — Broadcasts unread count on notification creation. Sidebar bell badge updates without page reload. Uses async adapter (dev) / solid_cable (prod).

4. **Index page, not dropdown** — Consistent with the sidebar navigation paradigm. Dropdowns require complex JS and conflict with the `<details>` sidebar toggle. A dedicated page is simpler and more accessible.

5. **Self-exclusion** — The actor is never notified of their own actions. This is enforced in the fan-out jobs (`.where.not(id: actor_id)`).

6. **Idempotent notification creation** — Unique index + `rescue ActiveRecord::RecordNotUnique` prevents duplicate notifications if jobs are retried.

---

## Risks

1. **Action Cable in dev with Solid Queue** — The async adapter is in-process only. Jobs running in a separate Solid Queue process can't broadcast to the web process. Mitigation: real-time updates may not work in dev (acceptable); production uses solid_cable which handles cross-process.

2. **N+1 on notification index** — Polymorphic `includes(:notifiable)` loads each type separately. With 3 types this means at most 3 extra queries. Acceptable.

3. **Email volume** — A trip with 10 members generates 9 emails per journal entry. No digest/batch for V1 (YAGNI). Can add later if needed.

4. **`TripMemberships::Assign` signature change** — Adding `actor_id:` to the event payload requires updating the action and its callers. Only one controller calls it.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
mise x -- bundle exec brakeman -q
mise x -- bundle exec bundle-audit check
```

### Runtime Verification
- [ ] Bell icon visible in sidebar with unread count badge
- [ ] Create journal entry via MCP → notification appears for trip members
- [ ] Add comment → notification for subscribed users
- [ ] Self-notifications excluded (author/commenter not notified)
- [ ] Click notification → navigates to relevant resource
- [ ] Mark as read / mark all as read works
- [ ] Unfollow journal entry → no more comment notifications for that entry
- [ ] Re-follow → notifications resume
- [ ] Email sent on entry creation (check MailCatcher)
- [ ] Email sent on comment added (check MailCatcher)
- [ ] No email for unfollowed entries
- [ ] All existing tests still pass
- [ ] No Bullet N+1 alerts

### Definition of Done
- [ ] `notifications` and `journal_entry_subscriptions` tables created
- [ ] Notification model with polymorphic notifiable, scopes, mark_as_read
- [ ] NotificationSubscriber wired for journal_entry.created and comment.created
- [ ] TripMembershipSubscriber dispatches member_added notification
- [ ] NotificationMailer sends email for entry_created and comment_added
- [ ] Action Cable broadcasts unread count on notification creation
- [ ] Bell icon in sidebar with real-time badge count
- [ ] Notifications index page with mark-as-read actions
- [ ] Follow/unfollow button on journal entry show page
- [ ] Auto-subscribe on entry creation and comment creation
- [ ] All specs pass, lint clean, Brakeman clean
