# Phase 11 - UI Designer Review: Notification Center

**Branch:** `feature/phase-11-notification-center`
**Reviewer:** UI Designer
**Date:** 2026-03-27

---

## 1. Scope Assessment

Phase 11 adds a full notification center to the application: bell icon in sidebar/mobile nav with an unread badge, a notifications index page with date grouping, notification card components, follow/unfollow on journal entries, and an empty state. The UI-relevant files are:

| File | Type | Description |
|------|------|-------------|
| `app/components/notification_bell.rb` | New component | Bell nav item with unread count badge |
| `app/components/notification_card.rb` | New component | Individual notification row with indicator, content link, and mark-read action |
| `app/components/journal_entry_follow_button.rb` | New component | Follow/unfollow toggle button for journal entries |
| `app/components/icons/bell.rb` | New icon | 20x20 SVG bell icon |
| `app/views/notifications/index.rb` | New view | Notifications index page with date grouping and empty state |
| `app/components/sidebar.rb` | Modified | Added NotificationBell render in main nav |
| `app/components/mobile_bottom_nav.rb` | Modified | Added "Alerts" tab linking to notifications |
| `app/views/journal_entries/show.rb` | Modified | Added follow button to action bar |
| `app/javascript/controllers/notification_badge_controller.js` | New Stimulus | Real-time badge updates via ActionCable |
| `app/controllers/notifications_controller.rb` | New controller | Index, mark_as_read, mark_all_as_read actions |
| `app/controllers/journal_entry_subscriptions_controller.rb` | New controller | Create/destroy subscription endpoints |
| `app/controllers/application_controller.rb` | Modified | Added `unread_notification_count` helper |

---

## 2. Component-by-Component Review

### 2.1 NotificationBell (`app/components/notification_bell.rb`)

**Library mapping:** Adapted from `application_ui/navigation/sidebar_navigation`. No direct variant -- custom composition combining `NavItem::NAV_BASE` styling with an absolute-positioned badge.

**Architecture: Good**

- 40 lines, well under limits. Two private methods (`render_badge`, `active?`) with clear single responsibilities.
- Reuses `NAV_BASE` from `Components::NavItem` to maintain sidebar alignment consistency. This is the correct approach -- sharing the base CSS string ensures the bell item aligns identically with other nav items.
- The `active?` method checks `controller_name == "notifications"` which follows the same pattern as other nav items.

**Design token usage: Correct**

- Badge uses `bg-red-500` and `text-white` for high-contrast urgency signaling. The red is a standard Tailwind utility, not a project CSS variable -- this is acceptable since alert badges are universally red and do not need to follow the theme accent color.
- Badge text size `text-[10px]` with `font-bold` is appropriate for a compact counter. The arbitrary value `text-[10px]` is a JIT class.
- The `ha-rise` entrance animation with `animation-delay: 100ms` provides staggered appearance consistent with adjacent nav items.

**Tailwind JIT classes used:**

- `text-[10px]` -- arbitrary value, requires rebuild if first use. Already present in `MobileBottomNav` (`text-[10px]`), so this class is already compiled.
- `-top-1`, `-right-1`, `min-w-5`, `h-5` -- standard Tailwind utilities. `-top-1` and `-right-1` may need verification.
- `hidden` -- conditionally applied when count is zero.

**Badge positioning:**

- `absolute -top-1 -right-1` positions the badge at the top-right corner of the bell icon link. The parent has `relative` for proper anchor.
- `flex h-5 min-w-5 items-center justify-center rounded-full px-1` creates a pill badge that expands for multi-digit counts. The minimum width `min-w-5` (20px) ensures the badge is circular for single digits.
- The `99+` overflow cap at `count > 99` prevents the badge from growing excessively.

**Stimulus integration:**

- The wrapping `div(data: { controller: "notification-badge" })` correctly scopes the Stimulus controller.
- The badge `span` has `data: { notification_badge_target: "count" }` for real-time updates via ActionCable.
- The `notification_badge_controller.js` correctly toggles the `hidden` class and updates text content. Clean and minimal.

**Observation:** The `view_context.unread_notification_count` call executes a database query on every page load (from `ApplicationController`). This is cached in an instance variable (`@unread_notification_count`) per request, which is correct. For high-traffic scenarios, consider moving to a counter cache or Redis key, but this is adequate for the current scale.

---

### 2.2 NotificationCard (`app/components/notification_card.rb`)

**Library mapping:** Adapted from `application_ui/lists/stacked_lists/narrow_with_actions.html`. The library pattern uses a flex row with avatar, text content, and an action button. The project adaptation replaces the avatar with an unread indicator dot, uses ha-card as the container, and replaces the static "View" action with a form-based "Mark read" button.

**Architecture: Good**

- 107 lines -- above the recommended 100-line class guideline but manageable. The component handles four concerns: indicator dot, linked content, action button, and event-type description mapping. If more event types or richer notification content are added, extracting the description/path resolution into a dedicated `NotificationPresenter` or strategy pattern would be warranted.
- Seven private methods, each under 15 lines.

**Design token usage: Correct**

- `ha-card` provides the rounded container, border, background, and shadow. This matches all other card components in the project.
- `bg-[var(--ha-primary)]` for the unread indicator dot correctly uses the project's primary accent color, adapting between light (`#00668a`) and dark (`#7bd0ff`) modes.
- `text-[var(--ha-muted)]` for the timestamp correctly uses the project's muted text color.
- `text-[var(--ha-primary)]` for the "Mark read" link uses the accent color as a clickable text action, consistent with other inline actions.

**Visual states:**

- **Unread:** Full opacity, blue indicator dot (`bg-[var(--ha-primary)]`), "Mark read" button visible.
- **Read:** `opacity-60` dimming, transparent indicator dot (`bg-transparent`), no action button. The dimming provides clear visual hierarchy without completely hiding read notifications.

**Layout:**

- `p-4 flex items-start gap-4` provides compact card padding with aligned content start. The `items-start` ensures the indicator dot and text top-align correctly.
- `flex-1 min-w-0` on the content area allows text truncation without overflowing the card.
- `flex-shrink-0` on both the indicator dot and action button prevents them from collapsing.

**Content linking:**

- The `render_content` method wraps the entire text area in a `link_to` when a `target_path` exists, making the notification clickable. When the notifiable record is deleted (nil), it falls back to a non-linked `div`.
- The `target_path` method handles three polymorphic types (`TripMembership`, `JournalEntry`, `Comment`) with correct routing. The `case/when` structure is clear and extensible.

**Actor name resolution:**

- `actor_name` falls back to "Someone" when actor is nil, then tries `name.presence` before splitting email at `@`. This matches the convention used in `Sidebar#user_display_name`.

**Observation:** The `description` method maps `event_type` to human-readable strings inline. As more event types are added, this should be extracted to an I18n key or a notification decorator to avoid the method growing beyond its scope.

---

### 2.3 JournalEntryFollowButton (`app/components/journal_entry_follow_button.rb`)

**Library mapping:** Adapted from `application_ui/elements/buttons/rounded_secondary_buttons.html`. Uses the project's `ha-button ha-button-secondary` classes which produce a rounded-full bordered button matching the library pattern.

**Architecture: Excellent**

- 35 lines. Single responsibility: render a Follow or Following button based on subscription state.
- Clean conditional branching with `if @subscribed` / `else`.
- `button_to` with `method: :post` for subscribing and `method: :delete` for unsubscribing. Correct RESTful verb usage.

**Design token usage: Correct**

- `ha-button ha-button-secondary` is the standard project button class for non-primary actions. This matches the "Edit", "Back to trip", and other action bar buttons on the same page.

**Placement:**

- Rendered inside `render_action_bar` on the journal entry show page (`app/views/journal_entries/show.rb`, line 78). It sits alongside "Edit", "Delete", and "Back to trip" buttons in a `flex flex-wrap gap-3` container. The visual weight is equal to sibling actions.
- Gated by `view_context.current_user` -- anonymous visitors do not see the button.

**Observation:** The button text changes between "Follow" and "Following" to indicate the current state. This is a standard toggle pattern. Consider adding a hover state text change (e.g., "Following" -> "Unfollow" on hover) in a future polish pass to make the destructive action clearer, but the current implementation is functionally correct.

---

### 2.4 Icons::Bell (`app/components/icons/bell.rb`)

**Library mapping:** Custom. No direct library source -- hand-crafted SVG matching the project's icon conventions.

**Architecture: Excellent**

- 25 lines. Inherits from `Components::Icons::Base` which provides `@css` (default `h-4 w-4`) and `@attrs`.
- Two SVG paths: bell body (stroke with `stroke-linejoin: round`) and clapper (stroke with `stroke-linecap: round`).

**Icon conventions: Correct**

- 20x20 viewBox, consistent with other project icons (Home, Map, Users, etc.).
- `fill: "none"`, `stroke: "currentColor"`, `stroke_width: "1.5"` -- matches the project's outlined icon style.
- `aria_hidden: "true"` correctly marks the icon as decorative.

**Usage:**

- In `NotificationBell` component (sidebar nav item).
- In `MobileBottomNav` (mobile "Alerts" tab).
- In `Views::Notifications::Index` empty state (`css: "h-12 w-12 mx-auto text-[var(--ha-muted)] mb-4"`).

The icon is reused in three contexts with appropriate size overrides, demonstrating correct abstraction.

---

### 2.5 Notifications Index View (`app/views/notifications/index.rb`)

**Architecture: Good**

- 93 lines. Follows the project's `Views::Base` pattern with `view_template` + private render methods.
- Uses `Components::PageHeader` with `section: "Activity"` and `title: "Notifications"`, consistent with other index pages.

**Layout structure:**

- `div(class: "space-y-8")` as the outermost container -- matches project convention for page sections.
- Date groups use `div(class: "space-y-3")` with `h3` headings and `div(class: "space-y-2")` for card spacing. The `space-y-3` between heading and cards, and `space-y-2` between cards, provides tight visual grouping.

**Date grouping:**

- Uses `group_by { |n| n.created_at.to_date }` for date bucketing. The `date_label` method converts `Date.current` to "Today", yesterday to "Yesterday", and older dates to `:long` format. This is a standard UX pattern.
- Date heading uses `text-sm font-semibold text-[var(--ha-on-surface-variant)]` -- correct for a section sub-heading. This is similar in spirit to the sticky headings in the reference library (`narrow_with_sticky_headings.html`) but without the sticky positioning, which is appropriate since the notification list is unlikely to be long enough to warrant it.

**Empty state:**

- Centered layout with `text-center py-16`.
- Large bell icon (`h-12 w-12 mx-auto`) in muted color, matching the reference library's empty state pattern (`application_ui/feedback/empty_states/simple.html`) which uses `mx-auto size-12 text-gray-400`.
- Title: `text-lg font-medium text-[var(--ha-on-surface-variant)]` -- "No notifications yet".
- Subtitle: `text-sm text-[var(--ha-muted)] mt-1` -- "You'll see activity from your trips here."
- No call-to-action button in the empty state. This is acceptable since there's no direct action a user can take to generate notifications -- they come from others' activity. The reference library empty state includes a "New Project" button, but it's intentionally omitted here.

**Mark all as read:**

- Rendered as a `button_to` with `ha-button ha-button-secondary` in the PageHeader action slot. Only shown when there are unread notifications (`@notifications.any? { |n| !n.read? }`).
- Uses PATCH method to `mark_all_as_read_notifications_path`.

---

## 3. Sidebar and Mobile Nav Integration

### Sidebar (`app/components/sidebar.rb`)

- Line 78: `render Components::NotificationBell.new` is placed between the "Trips" nav item (delay `80ms`) and the "Users" nav item (delay `120ms`).
- The bell component uses `animation-delay: 100ms` which falls correctly in the stagger sequence: Overview (40ms) -> Trips (80ms) -> Notifications (100ms) -> Users (120ms).
- The bell is gated by `logged_in?` (line 70), which is correct since anonymous users have no notifications.

### Mobile Bottom Nav (`app/components/mobile_bottom_nav.rb`)

- Line 20-21: `nav_tab(view_context.notifications_path, "Alerts", Components::Icons::Bell.new, notifications_active?)` is placed between "Trips" and "Users".
- The label "Alerts" is used instead of "Notifications" for brevity in the mobile tab bar. This is a good mobile UX decision -- the tab bar has limited horizontal space.
- `notifications_active?` checks `controller_name == "notifications"`, consistent with other active state checks.

**Observation:** The mobile bottom nav does not show an unread count badge on the "Alerts" tab. The sidebar NotificationBell component has a badge, but the mobile tab uses the generic `nav_tab` method which does not support badges. This is a minor asymmetry. If mobile badge support is desired in a future phase, the `nav_tab` method would need an optional `badge_count` parameter.

---

## 4. Design System Compliance

### CSS Variable Usage

| Variable | Usage | Correct? |
|----------|-------|----------|
| `--ha-primary` | Unread indicator dot, "Mark read" action text | Yes |
| `--ha-muted` | Timestamp text, empty state icon color | Yes |
| `--ha-on-surface-variant` | Date group headings, empty state title | Yes |

All three CSS variables have both light and dark mode values defined in `app/assets/tailwind/application.css`, so the notification components will render correctly in both themes.

### Component Class Usage

| Class | Usage | Correct? |
|-------|-------|----------|
| `ha-card` | NotificationCard container | Yes |
| `ha-button` | Mark all as read, Follow/Following | Yes |
| `ha-button-secondary` | Mark all as read, Follow/Following | Yes |
| `ha-overline` | PageHeader section label ("Activity") | Yes (via PageHeader) |
| `ha-nav-item` | NotificationBell base classes (via NAV_BASE) | Yes |
| `ha-nav-label` | NotificationBell "Notifications" text | Yes |
| `ha-rise` | NotificationBell entrance animation | Yes |

### Typography Scale

| Element | Classes | Consistent? |
|---------|---------|-------------|
| Page title | `text-4xl md:text-5xl font-bold` | Yes (via PageHeader) |
| Section overline | `ha-overline` | Yes |
| Date group heading | `text-sm font-semibold` | Yes |
| Notification text | `text-sm font-medium leading-snug` | Yes |
| Actor name | `font-semibold` (within text-sm) | Yes |
| Timestamp | `text-xs` | Yes |
| Badge count | `text-[10px] font-bold` | Yes |
| Empty state title | `text-lg font-medium` | Yes |
| Empty state subtitle | `text-sm` | Yes |

---

## 5. UI Component Library Sync

### New YAML Entries Created

| YAML File | Component | Library Source |
|-----------|-----------|---------------|
| `notification_bell.yml` | `Components::NotificationBell` | `application_ui/navigation/sidebar_navigation` |
| `notification_card.yml` | `Components::NotificationCard` | `application_ui/lists/stacked_lists` |
| `journal_entry_follow_button.yml` | `Components::JournalEntryFollowButton` | `application_ui/elements/buttons` |
| `icons_bell.yml` | `Components::Icons::Bell` | `null` (custom) |

All four entries document the library source, design tokens, and Tailwind classes used. The `ui_library/index.html` has been regenerated and now contains 18 components.

### Pre-existing YAML Entries

All 14 existing YAML entries remain valid and in sync. No existing component files were modified in ways that invalidate their YAML documentation.

---

## 6. Visual Verification (agent-browser)

All pages verified live at `https://catalyst.workeverywhere.docker/` using `agent-browser`. User authenticated as `joel@acme.org`.

### Pages Verified

| Page | Route | Result |
|------|-------|--------|
| Home (logged in) | `/` | Sidebar shows "Notifications" nav item between Trips and Users |
| Trips index | `/trips` | Sidebar shows "Notifications 3" (badge with unread count) |
| Notifications (empty) | `/notifications` | Empty state renders: large bell icon, "No notifications yet", subtitle |
| Notifications (with data) | `/notifications` | Date-grouped cards: "Today" and "Yesterday" sections, unread dots, "Mark read" buttons |
| Notifications (dark mode) | `/notifications` | Card backgrounds adapt, unread dots use dark-mode primary, text contrasts correct |
| Notifications (mobile) | `/notifications` (375px) | Bottom nav shows "ALERTS" tab, "Mark all as read" button visible, cards stack vertically |
| Journal entry show | `/trips/:id/journal_entries/:id` | "Following" button visible in action bar alongside Edit, Delete, Back to trip |

### Visual Quality Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Light mode rendering | Pass | Clean card separation, readable text hierarchy, muted timestamps |
| Dark mode rendering | Pass | Cards use surface-level backgrounds, primary accent visible on dots and actions |
| Mobile layout | Pass | Cards fill width, text wraps properly, bottom nav shows Alerts tab |
| Empty state | Pass | Centered, appropriately sized icon (h-12 w-12), clear messaging |
| Badge visibility | Pass | Red pill badge is visible against both light and dark sidebar backgrounds |
| Date grouping | Pass | "Today" and "Yesterday" labels render correctly with proper spacing |
| Read/unread distinction | Pass | Unread cards have blue dot and full opacity; read cards are dimmed to 60% |

---

## 7. Accessibility Assessment

| Criterion | Status | Notes |
|-----------|--------|-------|
| Bell icon `aria-hidden` | Pass | `aria_hidden: "true"` on SVG, text label "Notifications" in `ha-nav-label` span |
| Active page indicator | Pass | `aria: { current: "page" }` set when notifications controller is active |
| Mobile nav aria | Pass | Bottom nav has `aria-label: "Mobile navigation"` and active tab gets `aria-current: "page"` |
| Mark read button | Pass | `button_to` generates a proper form with submit button |
| Notification links | Pass | Each notification card wraps content in a link with descriptive text (actor + action + time) |
| Color contrast | Review | The unread indicator dot relies solely on color (`--ha-primary`) to indicate state. Consider adding a screen reader label like `span(class: "sr-only") { "Unread" }` for the dot |

---

## 8. Findings and Recommendations

### No Blocking Issues

All components follow the project's design system, use correct CSS variables, and render properly in both light and dark mode across desktop and mobile viewports.

### Minor Observations (Non-blocking)

1. **NotificationCard line count (107 lines):** Slightly above the 100-line class guideline. If more event types or notification actions are added, consider extracting the `description` and `target_path` methods into a `NotificationPresenter` concern.

2. **Mobile badge gap:** The mobile bottom nav "Alerts" tab does not show an unread count badge, while the desktop sidebar `NotificationBell` does. This is a minor asymmetry that could be addressed by adding an optional `badge_count` parameter to the `nav_tab` method.

3. **Unread dot accessibility:** The unread indicator dot communicates state through color alone. Adding a `span(class: "sr-only") { "Unread" }` inside the dot div would improve screen reader support.

4. **Notification click behavior:** Clicking a notification link currently navigates to the target page but does not automatically mark the notification as read. Users must click "Mark read" separately. Consider auto-marking on click in a future iteration.

5. **Follow button hover state:** The "Following" button does not change text on hover (e.g., to "Unfollow"). This is a common UI pattern that clarifies the destructive action. Non-blocking for this phase.

---

## 9. Conclusion

Phase 11 introduces four well-structured Phlex components and one Phlex view that integrate cleanly into the existing design system. The notification bell reuses sidebar nav conventions, the notification card adapts the stacked-list-with-actions pattern from the reference library, and the follow button uses standard project button styling. All components use the correct CSS variables for theme compatibility. The UI Component Library has been updated with four new YAML entries and the index regenerated.

**Verdict: Approved.** No design system violations. No blocking issues. The five minor observations above are suggestions for future phases.
