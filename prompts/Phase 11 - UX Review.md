# Phase 11 -- UX Review: Notification Center

**Branch:** feature/phase-11-notification-center
**Date:** 2026-03-27
**Reviewer:** Live browser verification via agent-browser + code inspection
**App URL:** https://catalyst.workeverywhere.docker/
**Test user:** joel@acme.org (Super Admin, email auth)
**Scope:** Notification bell, notification cards, follow/unfollow, notifications index, sidebar and mobile nav integration

---

## UX Review -- feature/phase-11-notification-center

### Broken (blocks usability)

- **B1. Follow/unfollow fails on non-writable trips (Access Denied):** `JournalEntrySubscriptionsController` -- The `authorize_entry!` before_action calls `authorize!(@journal_entry, with: JournalEntryPolicy)`, which maps the controller action name (`create`/`destroy`) to `JournalEntryPolicy#create?` and `#destroy?`. Both policies require `record.trip.writable?`. Following a journal entry is a read-level operation (opting into notifications), not a write operation. On finished, archived, or cancelled trips, the Follow button is rendered (because `render_follow_button` only checks `current_user` presence) but clicking it produces "Access denied -- You don't have permission to access this page." This was confirmed in the browser on the Patagonia Trek trip (state: archived). **Recommended fix:** Change `authorize_entry!` to authorize with `:show?` instead of the default action mapping: `authorize!(@journal_entry, to: :show?, with: JournalEntryPolicy)`. The `:show?` rule only requires trip membership, which is correct for subscriptions.

- **B2. Notification bell does not highlight when active:** `app/components/notification_bell.rb:12` -- The `NotificationBell` component uses `NAV_BASE` class but never applies `NAV_ACTIVE` (`bg-[var(--ha-primary-container)]/10 text-[var(--ha-primary)]`) when `active?` returns true. Compare with `NavItem` (`nav_item.rb:22-23`) which conditionally appends `NAV_ACTIVE`. When on the Notifications page, the bell link looks identical to its idle state. The `aria: { current: "page" }` is set correctly but the visual highlight is missing. Confirmed visually: the Notifications link in the sidebar has no background highlight when on the notifications page, while other nav items (Overview, Trips) do highlight. **Recommended fix:** Add `NAV_ACTIVE` when active:
  ```ruby
  css = "#{NAV_BASE} ha-rise relative"
  css = "#{css} #{Components::NavItem::NAV_ACTIVE}" if active?
  ```

- **B3. Mobile label "Alerts" is inconsistent with "Notifications" everywhere else:** `app/components/mobile_bottom_nav.rb:20` -- The mobile bottom nav uses "Alerts" while the sidebar, page header, page title, controller, and routes all use "Notifications." Confirmed visually at 375px: the bottom tab says "ALERTS" but the page heading says "Notifications." This naming dissonance confuses users. **Recommended fix:** Change `"Alerts"` to `"Notifs"` (fits the 10px uppercase label) or `"Notifications"` if space permits.

- **B4. No pagination on notifications index:** `app/controllers/notifications_controller.rb:9-10` -- The controller loads `current_user.notifications.recent.includes(:actor)` with no limit. The `recent` scope is `order(created_at: :desc)` with no cap. For active users, this loads unbounded records, causing slow page loads, high memory usage, and an extremely long scrolling page. **Recommended fix:** Add `.limit(100)` as an immediate safety net. Then implement Pagy-based pagination.

---

### Friction (degrades experience)

- **F1. Follow/unfollow triggers a full-page redirect:** `app/controllers/journal_entry_subscriptions_controller.rb:12-14,17-20` -- Both `create` and `destroy` redirect to `[@trip, @journal_entry]`, causing a full page reload for what should be an instant toggle. The user loses scroll position. Confirmed in browser: clicking Follow scrolls to top after redirect. **Recommendation:** Wrap the button in a Turbo Frame and respond with a Turbo Frame replacement for instant toggle.

- **F2. Follow and Following buttons are visually identical:** `app/components/journal_entry_follow_button.rb:14-31` -- Both "Follow" and "Following" states use `ha-button ha-button-secondary`. There is no visual distinction. Confirmed visually on journal entry show page: both states look the same. **Recommendation:** Use `ha-button-primary` for "Following" state, or add a checkmark icon prefix.

- **F3. Mark-as-read triggers full-page redirect:** `app/controllers/notifications_controller.rb:16-20` -- Both `mark_as_read` and `mark_all_as_read` redirect to `notifications_path`. Confirmed in browser: clicking "Mark read" or "Mark all as read" causes a full page reload. The toast feedback ("Notification marked as read" / "All notifications marked as read") works correctly. **Recommendation:** Use Turbo Stream responses for in-place updates.

- **F4. Mobile bottom nav has no badge count:** `app/components/mobile_bottom_nav.rb:20-21` -- The sidebar bell shows a red badge with unread count updated via ActionCable. The mobile bottom nav renders the bell as a plain `nav_tab` with no badge. Confirmed at 375px: no indication of unread notifications until the user taps the tab. **Recommendation:** Add a badge indicator (even a simple dot) to the mobile bell tab.

- **F5. "Mark read" button tap target may be undersized on mobile:** `app/components/notification_card.rb:63-69` -- The button uses `text-xs` with no padding. Rendered height is approximately 18px, below WCAG 2.5.8's 24px recommendation. **Recommendation:** Add `py-1.5` to the button class.

- **F6. N+1 query on notification card target paths:** `app/controllers/notifications_controller.rb:10` -- The controller eager-loads `:actor` but not `:notifiable`. Each card triggers separate queries for `notifiable`, `notifiable.trip`, and `notifiable.journal_entry.trip`. **Recommendation:** Add `.includes(notifiable: [:trip])` to the controller query.

- **F7. Notification card link area is narrower than the visual card:** `app/components/notification_card.rb:37-45` -- Only the middle content area is a link. The unread dot and "Mark read" button are outside the link. The effective clickable area is roughly 70% of the card width. **Recommendation:** Make the entire card clickable with a stretched-link pattern, or add hover highlight to indicate the clickable zone.

- **F8. No hover state on notification card links:** `app/components/notification_card.rb:39` -- The link uses `group` class but no `group-hover` classes are applied. There is no visual feedback that the card content is clickable until cursor changes. **Recommendation:** Add `group-hover:underline` to the text or `group-hover:bg-[var(--ha-surface-low)]` to the card.

---

### Suggestions (nice to have)

- **S1. Badge count has no accessible label:** The badge span contains only a number (e.g., "3") with no `aria-label`. A screen reader reads "Notifications 3" which is passable but not ideal. Adding `aria: { label: "#{count} unread" }` would improve clarity.

- **S2. Unread indicator dot relies on color alone (WCAG 1.4.1):** The read/unread distinction uses a colored dot (`bg-[var(--ha-primary)]` vs `bg-transparent`) and opacity. There is no shape, text, or ARIA difference. Adding a visually hidden "Unread" label or a "New" badge would address WCAG 1.4.1.

- **S3. Add "Mark as unread" for reversibility:** Marking a notification read is one-way. Users who accidentally mark-all-as-read cannot recover. An "Mark unread" action on read cards would provide undo capability.

- **S4. Notification description could include the entry name:** The text "commented on a journal entry" is generic. Including the entry title (e.g., "commented on *Day 3 in Kyoto*") would make notifications more scannable and useful.

- **S5. Date grouping could include a count:** Headers like "Today" could show "Today (3)" to help users gauge activity volume at a glance.

- **S6. Real-time badge update depends on ActionCable adapter:** In development, the `async` adapter only works within a single process. Notifications created via background jobs may not trigger real-time badge updates. This is an infrastructure concern, not a code bug, but should be documented.

- **S7. Consider auto-subscribing entry creators:** `NotifyCommentAddedJob` notifies `entry.subscribers`, but an entry creator is only subscribed if they explicitly follow their own entry. The `auto_subscribe_author` method in `Actions::JournalEntries::Create` handles this, but verify it is called in all entry creation paths.

---

## Checklist Assessment

### Flow and Clarity

| Check | Status | Notes |
|---|---|---|
| Primary action obvious | Pass | Bell icon in nav, "Mark all as read" in header |
| Error states visible | N/A | No form validation; controller uses `find` (404) |
| Success states confirmed | Pass | Flash toasts for mark read, follow, unfollow all verified |
| Multi-step flows connected | Pass | Notification card links navigate to source resource |
| Empty states handled | Pass | Bell icon + "No notifications yet" + helpful subtext |

### Forms

| Check | Status | Notes |
|---|---|---|
| Labels on inputs | N/A | No forms with text inputs |
| Submit button clear | N/A | Buttons use standard ha-button styles |
| Validation errors inline | N/A | No user input validation in this phase |
| Keyboard submittable | Pass | Follow/mark-read buttons are `button_to` forms |

### Navigation

| Check | Status | Notes |
|---|---|---|
| Active page highlighted | **Fail** | Bell does not apply `NAV_ACTIVE` (B2) |
| "Back to" links present | N/A | Single-page list, no deep navigation |
| Page title reflects content | Pass | Section: "Activity", Title: "Notifications" |
| Section labels make sense | Pass | PageHeader correctly configured |

### Authorization-Aware UI

| Check | Status | Notes |
|---|---|---|
| Actions hidden without permission | **Partial** | Follow button shown on non-writable trips but fails on click (B1) |
| No phantom buttons | **Fail** | Follow button visible but leads to Access Denied (B1) |
| "Members" link visible to viewers | N/A | Not modified in this phase |
| "New entry" hidden on non-writable | N/A | Not modified in this phase |

### Accessibility

| Check | Status | Notes |
|---|---|---|
| Keyboard reachable | Pass | All elements are links or `button_to` forms |
| Distinguishable by more than color | **Partial** | Unread dot is color-only (S2); opacity provides secondary signal |
| Text contrast sufficient | Pass | Design tokens ensure proper contrast in both modes |
| Icons meaningful to screen readers | Pass | Bell SVG has `aria_hidden: true`, link text provides meaning |

### PWA and In-Place Updates

| Check | Status | Notes |
|---|---|---|
| Service worker skips non-GET | Pass | `request.method !== "GET"` check at line 34 |
| No stale caches | Pass | Cache versioned with `GIT_SHA` |
| Mark read works (PATCH) | Pass | Redirects correctly, toast confirmation shown |
| Mark all as read works (PATCH) | Pass | All cards transition to read state, toast shown |
| Follow works (POST) | **Partial** | Works on writable trips, Access Denied on non-writable (B1) |
| Unfollow works (DELETE) | **Partial** | Works on writable trips, same B1 issue |

### Responsive

| Check | Status | Notes |
|---|---|---|
| Layout holds at 375px | Pass | Cards stack properly, no horizontal scroll |
| Touch targets adequate | **Partial** | "Mark read" button is undersized (F5) |

---

## Screenshots Reviewed

- Homepage (logged out, desktop) -- sidebar without bell icon: correct
- Homepage (logged in, desktop) -- sidebar with Notifications link and badge: correct
- Notifications index, empty state (light mode, desktop) -- bell icon, message, subtext: correct
- Notifications index, empty state (dark mode, desktop) -- readable, good contrast
- Notifications index, populated (light mode, desktop) -- Today/Yesterday groups, read/unread distinction, Mark all as read button, Mark read per-card
- Notifications index, populated (dark mode, desktop) -- good contrast, cards visible
- Notifications index, populated (light mode, mobile 375px) -- layout holds, bottom nav "ALERTS" active
- Notifications index (dark mode, mobile 375px) -- cards and bottom nav readable
- After "Mark read" single notification -- toast feedback, card transitions to read state
- After "Mark all as read" -- toast feedback, all cards dimmed, no Mark read buttons, no Mark all button
- Journal entry show with "Follow" button (light, writable trip) -- button in action bar
- Journal entry show with "Following" state (after follow) -- flash banner, button label changed
- After unfollow -- toast feedback, button reverts to "Follow"
- Journal entry show "Follow" on non-writable trip -- Access Denied page (B1)
- Notification card link click -- navigates to correct target resource

---

## Files Reviewed

| File | Role |
|---|---|
| `app/components/notification_bell.rb` | Bell icon + badge in sidebar |
| `app/components/notification_card.rb` | Individual notification display |
| `app/components/journal_entry_follow_button.rb` | Follow/unfollow toggle |
| `app/views/notifications/index.rb` | Notifications page with date groups |
| `app/components/sidebar.rb` | Sidebar nav with bell placement |
| `app/components/mobile_bottom_nav.rb` | Mobile nav with bell tab |
| `app/components/nav_item.rb` | NavItem for comparison (active state) |
| `app/components/icons/bell.rb` | Bell SVG icon |
| `app/controllers/notifications_controller.rb` | Index, mark_as_read, mark_all_as_read |
| `app/controllers/journal_entry_subscriptions_controller.rb` | Follow/unfollow |
| `app/controllers/application_controller.rb` | `unread_notification_count` helper |
| `app/views/journal_entries/show.rb` | Journal entry page with follow button |
| `app/models/notification.rb` | Notification model + scopes |
| `app/policies/journal_entry_policy.rb` | Authorization rules causing B1 |
| `app/javascript/controllers/notification_badge_controller.js` | Real-time badge via ActionCable |
| `app/views/pwa/service-worker.js.erb` | Service worker non-GET skip check |
| `db/migrate/20260327100001_create_notifications.rb` | Notification schema |
