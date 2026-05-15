# frozen_string_literal: true

module Views
  module AuditLogs
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, audit_logs:, show_low_signal: false)
        @trip = trip
        @audit_logs = audit_logs
        @show_low_signal = show_low_signal
      end

      def view_template
        div(class: "space-y-8") do
          render_header
          render_feed
        end
      end

      private

      def render_header
        render Components::PageHeader.new(
          section: @trip.name, title: "Activity"
        ) do
          render_low_signal_toggle
          link_to("Back to trip", view_context.trip_path(@trip),
                  class: "ha-button ha-button-secondary")
        end
      end

      def render_low_signal_toggle
        if @show_low_signal
          link_to("Hide low-signal",
                  view_context.trip_audit_logs_path(@trip),
                  class: "ha-button ha-button-secondary")
        else
          link_to("Show low-signal",
                  view_context.trip_audit_logs_path(@trip, low_signal: 1),
                  class: "ha-button ha-button-secondary")
        end
      end

      def render_feed
        if @audit_logs.any?
          div(
            class: "flex flex-col gap-8",
            data: {
              controller: "audit-log-feed",
              audit_log_feed_trip_id_value: @trip.id,
              audit_log_feed_show_low_signal_value: @show_low_signal
            }
          ) do
            render_stream_target
            render_groups
            render_load_older
          end
        else
          render_empty_state
        end
      end

      # New live rows are prepended here by the audit-log-feed controller.
      def render_stream_target
        div(id: "audit_log_stream",
            data: { audit_log_feed_target: "list" })
      end

      def render_groups
        @audit_logs.group_by { |l| l.occurred_at.to_date }
                   .each do |date, logs|
          section do
            h3(class: "font-headline text-sm font-semibold " \
                      "text-[var(--ha-on-surface-variant)] mb-4 px-2") do
              plain date_label(date)
            end
            div(class: "flex flex-col gap-3") do
              logs.each do |log|
                render Components::AuditLogCard.new(audit_log: log)
              end
            end
          end
        end
      end

      def render_load_older
        return if @audit_logs.size < 50

        oldest = @audit_logs.last.occurred_at
        link_to(
          "Load older",
          view_context.trip_audit_logs_path(
            @trip, before: oldest.iso8601,
                   low_signal: (@show_low_signal ? 1 : nil)
          ),
          class: "ha-button ha-button-secondary self-center"
        )
      end

      def render_empty_state
        div(class: "flex flex-col items-center justify-center " \
                   "py-16 px-8") do
          div(
            class: "w-full max-w-sm flex flex-col items-center " \
                   "space-y-6 py-16 px-8 rounded-2xl " \
                   "bg-[var(--ha-card)]/40 backdrop-blur-md " \
                   "border border-white/20 dark:border-white/10"
          ) do
            render Components::Icons::Clock.new(
              css: "h-12 w-12 text-[var(--ha-primary)]/40"
            )
            h3(class: "font-headline text-lg font-semibold " \
                      "text-[var(--ha-on-surface)]") do
              plain "No activity yet"
            end
            p(class: "text-sm text-[var(--ha-on-surface-variant)] " \
                     "text-center") do
              plain "Actions taken on this trip will appear here."
            end
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
