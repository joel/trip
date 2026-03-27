# Notification Center

In-app notifications with email delivery, real-time badge updates, and follow/unfollow for journal entries.

> Open [`docs/notification-center.excalidraw`](notification-center.excalidraw) in [excalidraw.com](https://excalidraw.com) for the interactive diagram.

## Architecture

```
  Action (JournalEntries::Create, Comments::Create, TripMemberships::Assign)
       |
       | Rails.event.notify (with actor_id)
       v
  Subscribers
       | NotificationSubscriber      -- journal_entry.created, comment.created
       | TripMembershipSubscriber    -- trip_membership.created (also sends assignment email)
       v
  Fan-Out Jobs
       | NotifyEntryCreatedJob       -- iterates trip.members, excludes author
       | NotifyCommentAddedJob       -- iterates entry.subscribers, excludes commenter
       v
  Per-Recipient (for each member/subscriber)
       |
       +---> CreateNotificationJob   -- Notification.create! + ActionCable broadcast
       |         |
       |         v
       |     ActionCable             -- notifications:user_{id} -> { unread_count: N }
       |         |
       |         v
       |     Stimulus Controller     -- notification-badge updates bell icon badge
       |
       +---> NotificationMailer      -- entry_created / comment_added email
```

## Models

### Notification

Polymorphic notification record linking an event to a recipient.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `notifiable_type` | string | `TripMembership`, `JournalEntry`, or `Comment` |
| `notifiable_id` | uuid | FK to the triggering record |
| `recipient_id` | uuid | FK(users) -- who receives the notification |
| `actor_id` | uuid | FK(users) -- who triggered it |
| `event_type` | integer | `member_added(0)`, `entry_created(1)`, `comment_added(2)` |
| `read_at` | datetime | null = unread |

**Unique index:** `(notifiable_type, notifiable_id, recipient_id, event_type)` -- prevents duplicates, enables idempotent job retries.

**Scopes:** `unread`, `recent`
**Methods:** `read?`, `mark_as_read!`

### JournalEntrySubscription

Join table tracking who follows a journal entry for comment notifications.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `user_id` | uuid | FK(users) |
| `journal_entry_id` | uuid | FK(journal_entries) |
| `created_at` | datetime | No `updated_at` (create-or-destroy only) |

**Unique index:** `(user_id, journal_entry_id)`

## Notification Rules

| Event | Recipients | Exclude | Email? |
|-------|-----------|---------|--------|
| User added to trip | The added user | -- | No (separate assignment email) |
| Journal entry created | All trip members | Author | Yes |
| Comment added | All entry subscribers | Commenter | Yes |

## Auto-Subscribe

| When | Who is subscribed | To what |
|------|------------------|---------|
| Author creates a journal entry | Author | That journal entry |
| User posts a comment | Commenter | The parent journal entry |

Uses `find_or_create_by!` for idempotent subscription creation. Subscriptions are created synchronously in the Action (before `emit_event`), ensuring the subscriber list is current before fan-out jobs run.

## Follow / Unfollow

Users can unfollow a journal entry to stop receiving comment notifications:

- **Follow:** `POST /trips/:trip_id/journal_entries/:id/subscription`
- **Unfollow:** `DELETE /trips/:trip_id/journal_entries/:id/subscription`

Singular `resource :subscription` routing -- each user has at most one subscription per entry.

The button appears on the journal entry show page:
- "Following" (when subscribed) -- click to unfollow
- "Follow" (when not subscribed) -- click to follow

## Notifications UI

### Bell Icon (Sidebar + Mobile)

- Bell icon NavItem in sidebar between "Trips" and "Users"
- Unread count badge (red dot with number, hidden when 0)
- `notification-badge` Stimulus controller subscribes to `NotificationsChannel` via Action Cable
- Badge updates in real-time when notifications arrive (production only -- dev uses async adapter)
- Mobile bottom nav includes a bell tab

### Notifications Index Page

- **Route:** `GET /notifications`
- Lists notifications grouped by date (Today, Yesterday, older dates)
- Each card shows: actor name, action description, time ago, read/unread indicator
- Click navigates to the relevant resource (trip, entry, or entry with comments)
- "Mark read" per notification: `PATCH /notifications/:id/mark_as_read`
- "Mark all as read" bulk action: `PATCH /notifications/mark_all_as_read`
- Empty state with bell icon illustration

## Action Cable

### Connection

`app/channels/application_cable/connection.rb` authenticates via Rodauth session key (`:account_id`). Unauthenticated connections are rejected.

### NotificationsChannel

Streams to `notifications:user_{id}`. `CreateNotificationJob` broadcasts `{ unread_count: N }` after creating each notification.

**Dev limitation:** The async cable adapter is in-process only. Jobs running in a separate Solid Queue process cannot broadcast to the web process. Real-time badge updates work in production (solid_cable) but require page reload in development.

## Jobs

| Job | Purpose | Triggered By |
|-----|---------|-------------|
| `CreateNotificationJob` | Create one notification + broadcast unread count | Fan-out jobs or TripMembershipSubscriber |
| `NotifyEntryCreatedJob` | Fan-out to trip members (excl. author) | NotificationSubscriber |
| `NotifyCommentAddedJob` | Fan-out to entry subscribers (excl. commenter) | NotificationSubscriber |

### Idempotency

`CreateNotificationJob` rescues `ActiveRecord::RecordNotUnique`. If a job is retried after a successful first run, the duplicate insert hits the unique constraint and is silently ignored.

## Mailer

`NotificationMailer` with two methods:

| Method | Subject | Template |
|--------|---------|----------|
| `entry_created(journal_entry_id, recipient_id)` | "New entry in {trip}: {entry}" | `entry_created.text.erb` |
| `comment_added(comment_id, recipient_id)` | "New comment on {entry} in {trip}" | `comment_added.text.erb` |

Both use `find_by` with early return guard for safe async execution (records may be deleted between job enqueue and execution).

## Event Wiring

Registered in `config/initializers/event_subscribers.rb`:

```ruby
Rails.event.subscribe(NotificationSubscriber.new) do |e|
  e[:name].in?(%w[journal_entry.created comment.created])
end
```

`TripMembershipSubscriber` (already registered for `trip_membership.*`) was updated to also dispatch `CreateNotificationJob` for `member_added` notifications.

## Files

```
Models
  app/models/notification.rb
  app/models/journal_entry_subscription.rb

Jobs
  app/jobs/create_notification_job.rb
  app/jobs/notify_entry_created_job.rb
  app/jobs/notify_comment_added_job.rb

Subscriber
  app/subscribers/notification_subscriber.rb

Mailer
  app/mailers/notification_mailer.rb
  app/views/notification_mailer/entry_created.text.erb
  app/views/notification_mailer/comment_added.text.erb

Channels
  app/channels/application_cable/connection.rb
  app/channels/application_cable/channel.rb
  app/channels/notifications_channel.rb

Controllers
  app/controllers/notifications_controller.rb
  app/controllers/journal_entry_subscriptions_controller.rb

Policy
  app/policies/notification_policy.rb

Views & Components
  app/views/notifications/index.rb
  app/components/notification_card.rb
  app/components/notification_bell.rb
  app/components/journal_entry_follow_button.rb
  app/components/icons/bell.rb

JavaScript
  app/javascript/controllers/notification_badge_controller.js

Diagram
  docs/notification-center.excalidraw
```

## Testing

```bash
# All notification-related specs
mise x -- bundle exec rspec spec/models/notification_spec.rb \
  spec/models/journal_entry_subscription_spec.rb \
  spec/jobs/create_notification_job_spec.rb \
  spec/jobs/notify_entry_created_job_spec.rb \
  spec/jobs/notify_comment_added_job_spec.rb \
  spec/requests/notifications_spec.rb \
  spec/requests/journal_entry_subscriptions_spec.rb \
  spec/system/notifications_spec.rb
```
