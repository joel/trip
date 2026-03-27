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
      css = "ha-card p-4 flex items-start gap-4 " \
            "transition-all duration-200"
      css = "#{css} opacity-60" if @notification.read?
      div(class: css) do
        render_indicator
        render_content
        render_actions
      end
    end

    private

    def render_indicator
      if @notification.read?
        div(class: "mt-1.5 h-2.5 w-2.5 rounded-full " \
                   "bg-transparent flex-shrink-0")
      else
        div(class: "mt-1.5 h-2.5 w-2.5 rounded-full " \
                   "bg-[var(--ha-primary)] flex-shrink-0")
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
      p(class: "text-sm font-medium leading-snug") do
        span(class: "font-semibold") do
          plain actor_name
        end
        plain " #{description}"
      end
      p(class: "text-xs text-[var(--ha-muted)] mt-1") do
        plain time_ago_in_words(@notification.created_at)
        plain " ago"
      end
    end

    def render_actions
      return if @notification.read?

      button_to(
        view_context.mark_as_read_notification_path(@notification),
        method: :patch,
        class: "text-xs text-[var(--ha-primary)] " \
               "hover:underline flex-shrink-0",
        form: { class: "inline-flex" }
      ) { "Mark read" }
    end

    def actor_name
      return "Someone" unless @notification.actor

      @notification.actor.name.presence ||
        @notification.actor.email.split("@").first
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
        view_context.trip_journal_entry_path(
          notifiable.trip, notifiable
        )
      when Comment
        view_context.trip_journal_entry_path(
          notifiable.journal_entry.trip,
          notifiable.journal_entry
        )
      end
    end
  end
end
