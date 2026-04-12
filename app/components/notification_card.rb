# frozen_string_literal: true

module Components
  class NotificationCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::TimeAgoInWords

    def initialize(notification:)
      @notification = notification
    end

    def view_template
      div(class: card_css) do
        render_left_border unless @notification.read?
        render_avatar
        render_content
        render_actions
      end
    end

    private

    def card_css
      base = "relative overflow-hidden rounded-2xl p-5 " \
             "flex items-start gap-4 " \
             "motion-safe:transition-all motion-safe:duration-300"
      if @notification.read?
        "#{base} bg-[var(--ha-card)]/60 opacity-60 hover:opacity-100"
      else
        "#{base} bg-[var(--ha-card)] " \
          "shadow-[0_20px_40px_-12px_rgba(19,27,46,0.05)]"
      end
    end

    def render_left_border
      div(class: "absolute top-0 left-0 w-1 h-full " \
                 "bg-[var(--ha-primary)]")
    end

    def render_avatar
      css = "w-12 h-12 rounded-full flex-shrink-0 flex " \
            "items-center justify-center " \
            "bg-[var(--ha-surface-high)] " \
            "text-sm font-bold " \
            "text-[var(--ha-on-surface-variant)]"
      css = "#{css} grayscale" if @notification.read?
      div(class: css) do
        plain actor_initials
      end
    end

    def render_content
      path = target_path
      if path
        link_to(path, class: "flex-1 min-w-0 group") do
          render_text
        end
      else
        div(class: "flex-1 min-w-0") { render_text }
      end
    end

    def render_text
      div(class: "flex justify-between items-start") do
        p(class: "text-sm leading-snug") do
          span(class: "font-bold text-[var(--ha-on-surface)]") do
            plain actor_name
          end
          plain " "
          span(class: "text-[var(--ha-on-surface-variant)]") do
            plain description
          end
        end
      end
      div(class: "flex items-center gap-3 mt-1") do
        span(class: "text-[11px] font-medium " \
                    "text-[var(--ha-muted)]") do
          plain time_ago_in_words(@notification.created_at)
          plain " ago"
        end
      end
    end

    def render_actions
      return if @notification.read?

      button_to(
        view_context.mark_as_read_notification_path(@notification),
        method: :patch,
        class: "text-[11px] font-bold text-[var(--ha-primary)] " \
               "uppercase tracking-wider " \
               "hover:underline flex-shrink-0 " \
               "motion-safe:transition-all",
        form: { class: "inline-flex" }
      ) { "Mark read" }
    end

    def actor_name
      return "Someone" unless @notification.actor

      @notification.actor.name.presence ||
        @notification.actor.email.split("@").first
    end

    def actor_initials
      return "?" unless @notification.actor

      name = @notification.actor.name.presence
      if name
        name.split.map(&:first).first(2).join.upcase
      else
        @notification.actor.email.first.upcase
      end
    end

    def description
      case @notification.event_type
      when "member_added" then "added you to a trip"
      when "entry_created" then "created a new journal entry"
      when "comment_added" then "commented on a journal entry"
      else "did something"
      end
    end

    def target_path
      notifiable = @notification.notifiable
      return unless notifiable

      case notifiable
      when TripMembership
        view_context.trip_path(notifiable.trip)
      when JournalEntry
        view_context.trip_path(
          notifiable.trip,
          anchor: "journal_entry_#{notifiable.id}"
        )
      when Comment
        view_context.trip_path(
          notifiable.journal_entry.trip,
          anchor: "journal_entry_#{notifiable.journal_entry_id}"
        )
      end
    end
  end
end
