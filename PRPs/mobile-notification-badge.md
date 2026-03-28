# PRP: Mobile Notification Badge Bug Fix

**Status:** Draft
**Date:** 2026-03-28
**Type:** Bug Fix
**Confidence Score:** 9/10 (small, well-scoped change in a single component with clear pattern to follow)

---

## Problem Statement

The notification unread count badge is visible in the desktop sidebar but missing from the mobile bottom navigation bar. On mobile, tapping the "Notifs" tab navigates to the notifications page but gives no visual indicator of unread notifications.

**Desktop (works):** `Components::Sidebar` renders `Components::NotificationBell` which includes a red pill badge with unread count and a `notification-badge` Stimulus controller for real-time ActionCable updates.

**Mobile (broken):** `Components::MobileBottomNav` renders the notification tab as a plain `nav_tab` call with just a Bell icon and "Notifs" label -- no badge, no Stimulus controller, no unread count.

---

## Root Cause Analysis

**File:** `app/components/mobile_bottom_nav.rb`, lines 20-21

```ruby
nav_tab(view_context.notifications_path, "Notifs",
        Components::Icons::Bell.new, notifications_active?)
```

This uses the generic `nav_tab` method (line 35-50) which renders a link with icon + label text only. Compare with the desktop sidebar (`app/components/sidebar.rb`, line 78) which renders the dedicated `Components::NotificationBell` component that includes badge rendering and Stimulus controller wiring.

The `NotificationBell` component cannot be reused directly in the mobile nav because it's styled as a sidebar nav item (uses `NAV_BASE` classes: `ha-nav-item flex items-center gap-3 rounded-2xl px-4 py-3`) which doesn't match the mobile bottom nav's tab layout (vertical flex column with small text).

---

## Codebase Context

### Key Files

| File | Role | Lines |
|------|------|-------|
| `app/components/mobile_bottom_nav.rb` | **PRIMARY CHANGE** - Mobile nav, needs badge added | 85 lines |
| `app/components/notification_bell.rb` | **REFERENCE** - Desktop badge implementation to mirror | 45 lines |
| `app/javascript/controllers/notification_badge_controller.js` | Stimulus controller for real-time badge updates | 34 lines |
| `app/controllers/application_controller.rb` | `unread_notification_count` helper (line 33-35) | N/A |
| `app/components/sidebar.rb` | Desktop sidebar for comparison | 263 lines |

### How the Desktop Badge Works

1. `NotificationBell` (line 9) calls `view_context.unread_notification_count` for initial count
2. Wraps in `div(data: { controller: "notification-badge" })` (line 10)
3. Renders badge `span` with `data: { notification_badge_target: "count" }` (line 36)
4. Badge CSS: `absolute -top-1 -right-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-[var(--ha-danger-strong)] px-1 text-[10px] font-bold text-white`
5. Adds `hidden` class when count is zero (line 32)
6. Stimulus controller subscribes to ActionCable `NotificationsChannel`, toggles `hidden` class and updates text on `received` (lines 7-15, 24-33 of JS)

### How the Mobile Nav Tab Works

```ruby
def nav_tab(path, label, icon, active)
  active_css = "text-[var(--ha-primary)] scale-110"
  idle_css = "text-[var(--ha-muted)] hover:text-[var(--ha-primary)]"
  link_to(path, class: "flex flex-col items-center gap-0.5 px-3 py-2 ...") do
    render icon
    span(class: "text-[10px] font-medium uppercase tracking-widest") { label }
  end
end
```

The icon is rendered inline without a wrapper, so there's no `relative` container to anchor an absolute-positioned badge to.

---

## Implementation Plan

### Approach

Create a dedicated `notification_tab` method in `MobileBottomNav` that:
1. Wraps the entire tab in a `div` with the `notification-badge` Stimulus controller
2. Makes the icon wrapper `relative` so the badge can be positioned absolutely
3. Renders a small badge using the same pattern as `NotificationBell#render_badge`
4. Uses `view_context.unread_notification_count` for the initial server-rendered count

### Pseudocode

```ruby
# In mobile_bottom_nav.rb, replace:
#   nav_tab(view_context.notifications_path, "Notifs",
#           Components::Icons::Bell.new, notifications_active?)
# With:
#   notification_tab

def notification_tab
  count = view_context.unread_notification_count
  active = notifications_active?
  active_css = "text-[var(--ha-primary)] scale-110"
  idle_css = "text-[var(--ha-muted)] hover:text-[var(--ha-primary)]"

  div(data: { controller: "notification-badge" }) do
    a(
      href: view_context.notifications_path,
      class: "flex flex-col items-center gap-0.5 px-3 py-2 " \
             "transition-all duration-300 " \
             "#{active ? active_css : idle_css}",
      aria: { current: (active ? "page" : nil) }
    ) do
      # Icon wrapper needs `relative` for badge positioning
      div(class: "relative") do
        render Components::Icons::Bell.new
        render_notification_badge(count)
      end
      span(class: "text-[10px] font-medium uppercase tracking-widest") do
        plain "Notifs"
      end
    end
  end
end

def render_notification_badge(count)
  css = "absolute -top-1 -right-1.5 flex h-4 min-w-4 " \
        "items-center justify-center rounded-full " \
        "bg-[var(--ha-danger-strong)] px-0.5 " \
        "text-[8px] font-bold text-white"
  css = "#{css} hidden" if count.zero?
  label = "#{count} unread #{"notification".pluralize(count)}"
  span(
    class: css,
    data: { notification_badge_target: "count" },
    aria: { label: label }
  ) { count > 99 ? "99+" : count.to_s }
end
```

### Key Design Decisions

1. **Slightly smaller badge** than desktop (h-4/min-w-4 vs h-5/min-w-5, text-[8px] vs text-[10px]) because mobile nav tabs are more compact
2. **Same Stimulus controller** (`notification-badge`) for real-time updates -- the controller targets `[data-notification-badge-target="count"]` which works with multiple instances on the page
3. **Use `a` tag directly** instead of `link_to` helper to match the flexibility needed for wrapping (same approach as `NotificationBell`)
4. **Include `Phlex::Rails::Helpers::LinkTo`** is already included in the component, but we use a raw `a` tag here to keep the nesting clean

### Important: Stimulus Controller Multiple Instances

The `notification_badge_controller.js` creates a new ActionCable subscription per controller instance. With badge in both sidebar and mobile nav, there will be 2 subscriptions on desktop (sidebar is `hidden md:flex`, mobile is `md:hidden`). Each manages its own target independently. This is fine -- ActionCable handles multiple subscriptions gracefully, and only one is visible at any screen size.

---

## Tasks (in order)

1. **Modify `app/components/mobile_bottom_nav.rb`**
   - Replace the `nav_tab` call for notifications (lines 20-21) with a `notification_tab` method call
   - Add private `notification_tab` method with Stimulus controller wrapper and badge
   - Add private `render_notification_badge` method for the badge span

2. **Update `ui_library/mobile_bottom_nav.yml`**
   - Add `notification-badge` Stimulus controller reference
   - Add badge-related Tailwind classes to the class list
   - Update description to mention notification badge

3. **Add system test for mobile notification badge**
   - Test that the notification badge is visible in the mobile nav when there are unread notifications
   - Test that the badge is hidden when there are no unread notifications

4. **Run linting and tests**
   - `bundle exec rake project:fix-lint`
   - `bundle exec rake project:lint`
   - `bundle exec rake project:tests`
   - `bundle exec rake project:system-tests`

5. **Live verification**
   - Rebuild and restart app
   - Verify badge appears on mobile viewport at `https://catalyst.workeverywhere.docker`
   - Verify badge updates in real-time when new notifications arrive
   - Verify badge is hidden when all notifications are read
   - Verify desktop sidebar badge still works correctly

---

## Validation Gates

### Automated Tests

```bash
# Run all tests
bundle exec rake project:tests
bundle exec rake project:system-tests
```

### System Test Addition

Add to `spec/system/notifications_spec.rb`:

```ruby
it "shows unread badge in mobile navigation" do
  actor = create(:user)
  create(:notification,
         recipient: admin,
         actor: actor,
         notifiable: entry,
         event_type: :entry_created)

  visit root_path
  within("nav[aria-label='Mobile navigation']") do
    expect(page).to have_css("[data-notification-badge-target='count']", text: "1")
  end
end

it "hides badge in mobile navigation when no unread notifications" do
  visit root_path
  within("nav[aria-label='Mobile navigation']") do
    badge = find("[data-notification-badge-target='count']", visible: :all)
    expect(badge[:class]).to include("hidden")
  end
end
```

### Linting

```bash
bundle exec rake project:fix-lint
bundle exec rake project:lint
```

### Live Runtime Verification

```bash
bin/cli app rebuild
bin/cli app restart
```

Then verify with `agent-browser`:
- [ ] Mobile nav shows red badge with unread count
- [ ] Badge hidden when count is zero
- [ ] Badge updates in real-time via ActionCable
- [ ] Desktop sidebar badge still works
- [ ] No layout shift or overflow on mobile nav
- [ ] Badge number displays correctly for 1, 9, 99, 100+ counts

---

## Gotchas & Edge Cases

1. **Tailwind JIT**: The classes `h-4`, `min-w-4`, `text-[8px]`, `-right-1.5`, `px-0.5` may not be in the compiled CSS. If not, either use classes already present (`h-5`, `min-w-5`, `text-[10px]`, `-right-1`, `px-1` -- matching desktop) or trigger a Docker rebuild. Check the existing CSS first.

2. **Duplicate ActionCable subscriptions**: Both desktop and mobile badges will create separate ActionCable subscriptions. This is acceptable -- only one is visible at a time, and ActionCable handles this cleanly.

3. **`link_to` vs `a` tag**: The existing `nav_tab` uses `link_to`. The notification tab should use a raw `a` tag (like `NotificationBell` does) to allow nesting the Stimulus controller wrapper cleanly. Alternatively, keep `link_to` if nesting works.

4. **`pluralize` helper**: `NotificationBell` uses `"notification".pluralize(count)` for aria labels. Ensure `MobileBottomNav` has access to this (it should via `ActiveSupport`).

5. **Badge positioning with `flex-col` layout**: The mobile nav uses `flex flex-col items-center`. The badge needs to be positioned on the icon, not the entire tab. Wrapping just the icon in a `relative div` solves this.

---

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `app/components/mobile_bottom_nav.rb` | Modified | Add notification badge to mobile nav tab |
| `ui_library/mobile_bottom_nav.yml` | Modified | Update component documentation |
| `spec/system/notifications_spec.rb` | Modified | Add mobile badge tests |

---

## Workflow

Follow the `/github-workflow` skill:
1. Create GitHub issue for the bug
2. Move to Kanban board
3. Create feature branch
4. Implement fix
5. Run tests + linting
6. Live verification with agent-browser
7. Push branch and create PR

---

## Quality Checklist

- [x] All necessary context included (component code, Stimulus controller, helper method)
- [x] Validation gates are executable by AI (test commands, system test code, lint commands)
- [x] References existing patterns (mirrors `NotificationBell#render_badge`)
- [x] Clear implementation path (single file change + test + UI library update)
- [x] Error handling documented (Tailwind JIT, duplicate subscriptions, positioning)
- [x] Gotchas documented (5 edge cases identified)
