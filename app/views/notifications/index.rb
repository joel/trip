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
              class: "font-label text-xs font-semibold " \
                     "text-[var(--ha-primary)] px-4 py-2 " \
                     "rounded-full " \
                     "bg-[var(--ha-primary)]/5 " \
                     "hover:bg-[var(--ha-primary)]/10 " \
                     "motion-safe:transition-colors " \
                     "motion-safe:duration-300"
            )
          end
        end
      end

      def render_notifications
        if @notifications.any?
          div(class: "flex flex-col gap-8") do
            grouped = @notifications.group_by do |n|
              n.created_at.to_date
            end
            grouped.each do |date, notifications|
              render_date_group(date, notifications)
            end
          end
        else
          render_empty_state
        end
      end

      def render_date_group(date, notifications)
        section do
          h3(class: "font-headline text-sm font-semibold " \
                    "text-[var(--ha-on-surface-variant)] " \
                    "mb-4 px-2") do
            plain date_label(date)
          end
          div(class: "flex flex-col gap-3") do
            notifications.each do |notification|
              render Components::NotificationCard.new(
                notification: notification
              )
            end
          end
        end
      end

      def render_empty_state
        div(class: "flex flex-col items-center " \
                   "justify-center py-16 px-8") do
          render_empty_card
        end
      end

      def render_empty_card
        div(
          class: "w-full max-w-sm flex flex-col items-center " \
                 "justify-center space-y-8 py-16 px-8 " \
                 "rounded-2xl " \
                 "bg-[var(--ha-card)]/40 backdrop-blur-md " \
                 "border border-white/20 " \
                 "dark:border-white/10 " \
                 "shadow-[0_20px_40px_-12px_rgba(19,27,46,0.08)]"
        ) do
          render_empty_icon
          render_empty_text
          render_empty_cta
        end
      end

      def render_empty_icon
        div(class: "relative w-24 h-24 flex items-center " \
                   "justify-center") do
          div(class: "absolute inset-0 " \
                     "bg-[var(--ha-primary-container)]/20 " \
                     "rounded-full blur-xl")
          div(
            class: "relative w-16 h-16 rounded-full " \
                   "bg-[var(--ha-surface-high)] " \
                   "flex items-center justify-center"
          ) do
            render Components::Icons::Bell.new(
              css: "h-8 w-8 text-[var(--ha-primary)]/40"
            )
          end
        end
      end

      def render_empty_text
        div(class: "text-center space-y-2") do
          h3(class: "font-headline text-lg font-semibold " \
                    "text-[var(--ha-on-surface)]") do
            plain "No notifications yet"
          end
          p(class: "text-sm text-[var(--ha-on-surface-variant)] " \
                   "leading-relaxed px-4") do
            plain "You'll see activity from your trips here."
          end
        end
      end

      def render_empty_cta
        link_to(
          "Explore Trips",
          view_context.trips_path,
          class: "mt-4 px-8 py-3 " \
                 "ha-gradient-aura text-white " \
                 "rounded-full font-label text-sm " \
                 "font-semibold tracking-wide " \
                 "shadow-lg shadow-[var(--ha-primary)]/20 " \
                 "hover:-translate-y-px active:translate-y-0 " \
                 "motion-safe:transition-all " \
                 "motion-safe:duration-300"
        )
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
