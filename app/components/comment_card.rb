# frozen_string_literal: true

module Components
  class CommentCard < Components::Base
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::DOMID
    include Phlex::Rails::Helpers::TimeAgoInWords

    def initialize(trip:, journal_entry:, comment:)
      @trip = trip
      @entry = journal_entry
      @comment = comment
    end

    def view_template
      div(id: dom_id(@comment),
          class: "flex gap-3 rounded-lg bg-[var(--ha-surface)] " \
                 "p-4") do
        div(class: "flex-1") do
          render_header
          p(class: "mt-1 text-sm text-[var(--ha-text)]") do
            plain @comment.body
          end
        end
        render_actions
      end
    end

    private

    def render_header
      div(class: "flex items-center gap-2") do
        span(class: "text-sm font-semibold " \
                    "text-[var(--ha-text)]") do
          plain @comment.user.name || @comment.user.email
        end
        span(class: "text-xs text-[var(--ha-muted)]") do
          plain time_ago_in_words(@comment.created_at)
          plain " ago"
        end
      end
    end

    def render_actions
      return unless can_modify?

      div(class: "flex gap-1") do
        button_to(
          "Delete",
          view_context.trip_journal_entry_comment_path(
            @trip, @entry, @comment
          ),
          method: :delete,
          class: "text-xs text-red-500 hover:text-red-700",
          form: { class: "inline-flex" }
        )
      end
    end

    def can_modify?
      view_context.allowed_to?(:destroy?, @comment)
    end
  end
end
