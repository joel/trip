# Security Review -- feature/phase-11-notification-center

**Phase:** 11 - Notification Center
**Branch:** feature/phase-11-notification-center
**Date:** 2026-03-27
**Scope:** 60 files changed, +2340 / -21 lines

---

## Checklist Summary

### Authentication & Authorization

- [x] All new routes protected by `require_authenticated_user!`
  - `NotificationsController` has `before_action :require_authenticated_user!` (line 4).
  - `JournalEntrySubscriptionsController` has `before_action :require_authenticated_user!` (line 4).
- [x] Authorization checks present via `authorize!` (not just authentication)
  - `NotificationsController#index` calls `authorize!(Notification)`.
  - `NotificationsController#mark_as_read` calls `authorize!(@notification)` after scoping via `current_user.notifications.find(params[:id])`.
  - `NotificationsController#mark_all_as_read` calls `authorize!(Notification)` and scopes `current_user.notifications.unread`.
  - `JournalEntrySubscriptionsController` calls `authorize!(@journal_entry, with: JournalEntryPolicy)` which checks trip membership via `member?`.
- [x] New policies correctly check roles
  - `NotificationPolicy#update?` enforces `record.recipient_id == user.id` -- ownership check.
  - `NotificationPolicy#index?` and `mark_all_as_read?` only require a logged-in user.
  - `JournalEntrySubscriptionsController` delegates to `JournalEntryPolicy#show?` which requires `superadmin? || member?`.
- [x] Invitation/token flows are single-use and time-limited -- N/A for this phase.
- [x] Cannot bypass authorization by crafting a direct HTTP request
  - Subscription create/destroy is scoped to `current_user` -- you can only follow/unfollow yourself.
  - `mark_as_read` scopes lookup via `current_user.notifications.find(params[:id])` -- cannot mark another user's notification.
  - `mark_all_as_read` scopes via `current_user.notifications.unread` -- cannot affect another user's notifications.

### Input & Output

- [x] User input validated and sanitized
  - Subscription endpoints accept no user-supplied body params -- only path params for `trip_id` and `journal_entry_id`.
  - Notification endpoints accept only `:id` from path params (UUID).
  - No custom params are accepted (no `params.permit` needed since no form data is processed).
- [x] Strong parameters enforced -- N/A, no controller action in this diff accepts form body params.
- [x] Output escaped correctly
  - Phlex auto-escapes all output. No `unsafe_raw`, `html_safe`, or `raw` usage in any new file.
  - Email templates use ERB `<%= %>` which auto-escapes HTML context (though these are `.text.erb` templates, so HTML escaping is moot).
- [x] File uploads validated -- N/A for this phase.

### Data Exposure

- [x] Rendered views do not expose private fields
  - `NotificationCard#actor_name` shows `actor.name` or falls back to the local part of the email (`email.split("@").first`). This is consistent with how the rest of the app displays users. No password digests, tokens, or internal IDs are rendered.
- [x] Error messages are generic
  - Authorization failures render `Views::Shared::Forbidden` (403) via the global `rescue_from ActionPolicy::Unauthorized`.
  - `current_user.notifications.find(params[:id])` raises `ActiveRecord::RecordNotFound` (404) for IDs that don't belong to the user, which does not reveal whether the notification exists for another user.
- [x] Logs are free of sensitive values -- no custom logging added in this diff.
- [x] 403 response does not reveal resource existence -- the `set_notification` finder scopes to `current_user.notifications`, so an invalid ID returns 404 (not 403), which is the correct behavior for owned resources.

### Mass Assignment & Query Safety

- [x] No raw SQL fragments -- `update_all(read_at: Time.current)` is safe (no interpolation).
- [x] Policy checks applied before mutations
  - `mark_as_read` calls `authorize!(@notification)` before `@notification.mark_as_read!`.
  - `mark_all_as_read` calls `authorize!(Notification)` before the `update_all`.
  - Subscription create uses `find_or_create_by!(user: current_user)` -- only the current user can be subscribed.
- [x] Nested resources scoped correctly
  - `JournalEntrySubscriptionsController#set_journal_entry` uses `@trip.journal_entries.find(...)`, preventing cross-trip access.

### Secrets & Configuration

- [x] No secrets, tokens, or credentials hardcoded or committed.
- [x] Environment variables used correctly -- no new env vars introduced.
- [x] No `.env` or credentials files in the diff.

### Dependencies

- [x] No new gems added (Gemfile unchanged).
- `@rails/actioncable` was pinned in `importmap.rb` -- this is a Rails built-in, not a third-party dependency.

---

## Findings

### Critical (must fix before merge)

No critical issues found.

### Warning (should fix or consciously accept)

**W1: `notifiable_type` not validated in the Notification model**
`app/models/notification.rb` -- The `notifiable_type` column accepts any string. While `CreateNotificationJob` is the only writer and it always passes hardcoded type strings (`"JournalEntry"`, `"Comment"`, `"TripMembership"`), adding a model-level validation would be defense-in-depth against future misuse or job parameter tampering:

```ruby
validates :notifiable_type, inclusion: {
  in: %w[JournalEntry Comment TripMembership]
}
```

**Risk:** Low. All callers are internal jobs with hardcoded types. The unique index also limits abuse.

**W2: `actor_id NOT NULL` constraint may block user deletion in edge cases**
`db/migrate/20260327100001_create_notifications.rb:10-11` -- The `actor_id` column is `null: false` at the DB level, and `User` has `has_many :acted_notifications, dependent: :destroy`. This means deleting a user first destroys all notifications where they were the actor, which is correct. However, if the user was also the *recipient* of notifications created by themselves (e.g., self-assigned membership), both `dependent: :destroy` associations fire and the order depends on the association list. This is handled correctly since Rails destroys through both `notifications` and `acted_notifications` associations. No action needed, but worth documenting this behavior.

**W3: `NotificationCard#target_path` may raise on deleted notifiable**
`app/components/notification_card.rb:88-104` -- The `target_path` method calls `@notification.notifiable` then accesses nested associations like `notifiable.trip` or `notifiable.journal_entry.trip`. If the notifiable record has been deleted (e.g., a journal entry was removed), `notifiable` returns `nil` and the guard clause handles it. But if the notifiable exists while its *parent* was deleted (e.g., comment exists but journal_entry was deleted), this would raise `NoMethodError`. In practice this is unlikely because journal entries cascade-delete their comments, but a polymorphic target with a deleted intermediate record could cause a 500.

**Mitigation:** Add `rescue` in `target_path` or null-check intermediate associations. Low probability given cascade deletes.

### Informational (no action required)

**I1: Action Cable connection authentication is correctly implemented**
`app/channels/application_cable/connection.rb` reads `request.session[:account_id]` (Rodauth's session key), looks up the user, and calls `reject_unauthorized_connection` if not found. CSRF protection for WebSocket upgrades is enabled (the `disable_request_forgery_protection` line in `development.rb` is commented out). The channel streams only to `notifications:user_#{current_user.id}`, ensuring user isolation.

**I2: Notification scoping is correct -- users cannot see others' notifications**
- `NotificationsController#index` uses `current_user.notifications.recent`.
- `set_notification` uses `current_user.notifications.find(params[:id])`.
- `mark_all_as_read` uses `current_user.notifications.unread`.
- The `NotificationPolicy#update?` additionally checks `record.recipient_id == user.id`.
- This is a belt-and-suspenders approach (query scoping + policy check) -- no IDOR possible.

**I3: actor_id FK cleanup on user deletion is addressed**
`app/models/user.rb:22-24` declares `has_many :acted_notifications, dependent: :destroy`, which means deleting a user cascades to destroy all notifications where they were the actor. This prevents orphaned FK references. Combined with `has_many :notifications, dependent: :destroy` for recipient-side, both directions are covered.

**I4: Subscription endpoints correctly enforce trip membership**
`JournalEntrySubscriptionsController` delegates authorization to `JournalEntryPolicy`, which checks `superadmin? || member?`. A non-member gets a 403. The request spec at `spec/requests/journal_entry_subscriptions_spec.rb` explicitly tests this (`"forbids non-members from subscribing"`).

**I5: Email content does not leak sensitive data**
Both mailer templates (`entry_created.text.erb`, `comment_added.text.erb`) only include:
- Actor name or email (same as displayed in the app).
- Entry/trip names (which the recipient is a member of).
- A URL to view the entry (which is behind authentication).
No tokens, passwords, or internal IDs are exposed.

**I6: CreateNotificationJob is idempotent**
The job rescues `ActiveRecord::RecordNotUnique` (backed by the `idx_notifications_uniqueness` unique index), preventing duplicate notifications on job retries. This is correct defensive coding.

**I7: Action Cable broadcast is server-side only**
`CreateNotificationJob#broadcast_unread_count` broadcasts only `{ unread_count: count }` -- an integer. No notification content, user data, or internal IDs are pushed over the WebSocket. The Stimulus controller only updates the badge count.

**I8: No `unsafe_raw`, `html_safe`, or `raw` usage**
Confirmed across all new Phlex components and views. Phlex auto-escaping is the default.

### Not applicable

- **File uploads**: No file upload changes in this phase.
- **Invitation/token flows**: No new token-based flows introduced.
- **Rate limiting**: No new public-facing endpoints (all require authentication). Notification fan-out is bounded by trip membership count, which is inherently limited.

---

## Conclusion

Phase 11 demonstrates solid security practices throughout. All endpoints require authentication and authorization. Notification data is consistently scoped to the current user with both query scoping and policy checks (belt-and-suspenders). Action Cable authentication correctly leverages Rodauth sessions and streams are user-isolated. The fan-out jobs use hardcoded types and are idempotent. Email templates are minimal and do not leak sensitive data.

The only actionable warning (W1) is a defense-in-depth `notifiable_type` validation, which has low risk given the current architecture. W2 and W3 are edge cases with existing mitigations.

**Verdict: Clean to merge.** No critical or blocking issues found.
