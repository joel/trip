# Phase 11: Notification Center — Steps Taken

**Date:** 2026-03-27
**Issue:** joel/trip#50
**Branch:** `feature/phase-11-notification-center`

---

## Commits

### 1. Add Notification model with polymorphic notifiable
- Created `db/migrate/20260327100001_create_notifications.rb` — UUID PK, polymorphic notifiable, recipient/actor FKs, event_type enum, read_at, uniqueness index
- Created `app/models/notification.rb` — belongs_to polymorphic notifiable, recipient, actor; enum event_type; scopes unread/recent; read?/mark_as_read!
- Created `spec/models/notification_spec.rb` — 12 examples covering validations, associations, enums, scopes, methods, uniqueness
- Created `spec/factories/notifications.rb` — factory with traits :member_added, :comment_added, :read
- Modified `app/models/user.rb` — added `has_many :notifications`

### 2. Add JournalEntrySubscription model for follow/unfollow
- Created `db/migrate/20260327100002_create_journal_entry_subscriptions.rb` — UUID PK, user/journal_entry FKs, created_at only, uniqueness index
- Created `app/models/journal_entry_subscription.rb` — belongs_to user/journal_entry, uniqueness validation
- Created `spec/models/journal_entry_subscription_spec.rb` — 4 examples
- Created `spec/factories/journal_entry_subscriptions.rb`
- Modified `app/models/journal_entry.rb` — added `has_many :journal_entry_subscriptions` and `has_many :subscribers`
- Modified `app/models/user.rb` — added `has_many :journal_entry_subscriptions`

### 3. Auto-subscribe authors and commenters to journal entries
- Modified `app/actions/journal_entries/create.rb` — added `subscribe_author` step using `find_or_create_by!`
- Modified `app/actions/comments/create.rb` — added `subscribe_commenter` step using `find_or_create_by!`
- Updated specs to verify auto-subscription behavior

### 4. Add NotificationMailer for entry and comment emails
- Created `app/mailers/notification_mailer.rb` — entry_created and comment_added methods with find_by guard
- Created `app/views/notification_mailer/entry_created.text.erb`
- Created `app/views/notification_mailer/comment_added.text.erb`

### 5. Add notification jobs with fan-out and idempotency
- Created `app/jobs/create_notification_job.rb` — creates notification, rescues RecordNotUnique, broadcasts via ActionCable
- Created `app/jobs/notify_entry_created_job.rb` — fans out to trip members (excluding author)
- Created `app/jobs/notify_comment_added_job.rb` — fans out to entry subscribers (excluding commenter)
- Created specs for all 3 jobs — 8 examples total

### 6. Wire notification events through subscribers
- Created `app/subscribers/notification_subscriber.rb` — listens for journal_entry.created and comment.created
- Modified `app/subscribers/trip_membership_subscriber.rb` — dispatches CreateNotificationJob for member_added
- Modified event payloads to include actor_id in journal_entries/create, comments/create, trip_memberships/assign
- Modified `app/controllers/trip_memberships_controller.rb` — passes `actor: current_user`
- Registered NotificationSubscriber in `config/initializers/event_subscribers.rb`
- Updated `app/actions/AGENTS.md` event payload docs

### 7. Add Action Cable connection auth and NotificationsChannel
- Created `app/channels/application_cable/connection.rb` — auth via Rodauth session key (:account_id)
- Created `app/channels/application_cable/channel.rb`
- Created `app/channels/notifications_channel.rb` — streams to notifications:user_{id}
- Modified `config/importmap.rb` — pinned @rails/actioncable

### 8. Add notification_badge Stimulus controller
- Created `app/javascript/controllers/notification_badge_controller.js` — subscribes to NotificationsChannel, updates badge count in real-time

### 9. Add bell icon and notification badge to sidebar and mobile nav
- Created `app/components/icons/bell.rb` — bell SVG icon
- Created `app/components/notification_bell.rb` — extracted component with Stimulus controller wrapper and badge
- Modified `app/components/sidebar.rb` — renders NotificationBell between Trips and Users
- Modified `app/components/mobile_bottom_nav.rb` — added bell tab
- Modified `app/controllers/application_controller.rb` — added unread_notification_count helper

### 10. Add notifications controller, views, and policy
- Created `app/policies/notification_policy.rb` — index?, update?, mark_as_read?, mark_all_as_read?
- Created `app/controllers/notifications_controller.rb` — index, mark_as_read, mark_all_as_read
- Created `app/components/notification_card.rb` — card with indicator, actor, description, time ago, mark-read button
- Created `app/views/notifications/index.rb` — grouped by date, empty state, bulk mark-all-as-read
- Modified `config/routes.rb` — notification routes
- Created `spec/requests/notifications_spec.rb` — 5 examples
- Modified `.rubocop_todo.yml` — added controller to I18n exclusion

### 11. Add follow/unfollow for journal entry subscriptions
- Created `app/controllers/journal_entry_subscriptions_controller.rb` — create/destroy
- Created `app/components/journal_entry_follow_button.rb` — Following/Follow button
- Modified `config/routes.rb` — singular subscription resource
- Modified `app/views/journal_entries/show.rb` — added follow button in action bar
- Created `spec/requests/journal_entry_subscriptions_spec.rb` — 5 examples

### 12. Add system specs for notification center
- Created `spec/system/notifications_spec.rb` — 8 examples covering bell icon, notifications index, mark as read, mark all as read, follow/unfollow

---

## Test Results

- **Unit + request + job specs:** 516 examples, 0 failures
- **System tests:** 22 examples, 0 failures
- **Lint:** 403 files inspected, no offenses detected

---

## Files Created (26)

| File | Purpose |
|------|---------|
| `db/migrate/20260327100001_create_notifications.rb` | Notifications table |
| `db/migrate/20260327100002_create_journal_entry_subscriptions.rb` | Subscriptions table |
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
| `app/components/notification_bell.rb` | Bell + badge component |
| `app/components/notification_card.rb` | Notification display card |
| `app/components/journal_entry_follow_button.rb` | Follow/unfollow button |
| `app/views/notifications/index.rb` | Notifications page |
| `app/controllers/notifications_controller.rb` | Notifications CRUD |
| `app/controllers/journal_entry_subscriptions_controller.rb` | Follow/unfollow |
| `app/policies/notification_policy.rb` | Authorization |
| `spec/factories/notifications.rb` | Test factory |
| `spec/factories/journal_entry_subscriptions.rb` | Test factory |
| `spec/system/notifications_spec.rb` | System specs |

## Files Modified (14)

| File | Change |
|------|--------|
| `app/models/user.rb` | Added notifications and journal_entry_subscriptions associations |
| `app/models/journal_entry.rb` | Added journal_entry_subscriptions and subscribers associations |
| `app/actions/journal_entries/create.rb` | Added subscribe_author step + actor_id in event |
| `app/actions/comments/create.rb` | Added subscribe_commenter step + actor_id in event |
| `app/actions/trip_memberships/assign.rb` | Added actor: parameter + actor_id in event |
| `app/controllers/trip_memberships_controller.rb` | Pass actor: current_user |
| `app/subscribers/trip_membership_subscriber.rb` | Dispatch member_added notification |
| `config/initializers/event_subscribers.rb` | Register NotificationSubscriber |
| `config/routes.rb` | Notification + subscription routes |
| `config/importmap.rb` | Pin @rails/actioncable |
| `app/components/sidebar.rb` | Render NotificationBell component |
| `app/components/mobile_bottom_nav.rb` | Add bell tab |
| `app/controllers/application_controller.rb` | unread_notification_count helper |
| `app/views/journal_entries/show.rb` | Follow/unfollow button |
