# frozen_string_literal: true

module Components
  class NotificationBell < Components::Base
    NAV_BASE = Components::NavItem::NAV_BASE
    NAV_ACTIVE = Components::NavItem::NAV_ACTIVE

    def view_template
      count = view_context.unread_notification_count
      div(data: { controller: "notification-badge" }) do
        css = "#{NAV_BASE} ha-rise relative"
        css = "#{css} #{NAV_ACTIVE}" if active?
        a(
          href: view_context.notifications_path,
          class: css,
          style: "animation-delay: 100ms;",
          aria: active? ? { current: "page" } : {}
        ) do
          render Components::Icons::Bell.new
          span(class: "ha-nav-label") { "Notifications" }
          render_badge(count)
        end
      end
    end

    private

    def render_badge(count)
      css = "absolute -top-1 -right-1 flex h-5 min-w-5 " \
            "items-center justify-center rounded-full " \
            "bg-[var(--ha-danger-strong)] px-1 text-[10px] font-bold text-white"
      css = "#{css} hidden" if count.zero?
      label = "#{count} unread #{"notification".pluralize(count)}"
      span(
        class: css,
        data: { notification_badge_target: "count" },
        aria: { label: label }
      ) { count > 99 ? "99+" : count.to_s }
    end

    def active?
      view_context.controller_name == "notifications"
    end
  end
end
