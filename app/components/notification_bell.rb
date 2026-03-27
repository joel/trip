# frozen_string_literal: true

module Components
  class NotificationBell < Components::Base
    NAV_BASE = Components::NavItem::NAV_BASE

    def view_template
      count = view_context.unread_notification_count
      div(data: { controller: "notification-badge" }) do
        a(
          href: view_context.notifications_path,
          class: "#{NAV_BASE} ha-rise relative",
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
