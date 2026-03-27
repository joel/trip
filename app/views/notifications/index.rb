# frozen_string_literal: true

module Views
  module Notifications
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(notifications:)
        @notifications = notifications
      end

      def view_template
        div(class: "space-y-8") do
          render_header
          render_notifications
        end
      end

      private

      def render_header
        render Components::PageHeader.new(
          section: "Activity",
          title: "Notifications"
        ) do
          if @notifications.any? { |n| !n.read? }
            button_to(
              "Mark all as read",
              view_context.mark_all_as_read_notifications_path,
              method: :patch,
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end

      def render_notifications
        if @notifications.any?
          grouped = @notifications.group_by do |n|
            n.created_at.to_date
          end
          grouped.each do |date, notifications|
            render_date_group(date, notifications)
          end
        else
          render_empty_state
        end
      end

      def render_date_group(date, notifications)
        div(class: "space-y-3") do
          h3(class: "text-sm font-semibold " \
                    "text-[var(--ha-on-surface-variant)]") do
            plain date_label(date)
          end
          div(class: "space-y-2") do
            notifications.each do |notification|
              render Components::NotificationCard.new(
                notification: notification
              )
            end
          end
        end
      end

      def render_empty_state
        div(class: "text-center py-16") do
          render Components::Icons::Bell.new(
            css: "h-12 w-12 mx-auto text-[var(--ha-muted)] mb-4"
          )
          p(class: "text-lg font-medium " \
                   "text-[var(--ha-on-surface-variant)]") do
            plain "No notifications yet"
          end
          p(class: "text-sm text-[var(--ha-muted)] mt-1") do
            plain "You'll see activity from your trips here."
          end
        end
      end

      def date_label(date)
        if date == Date.current
          "Today"
        elsif date == Date.current - 1
          "Yesterday"
        else
          date.to_fs(:long)
        end
      end
    end
  end
end
