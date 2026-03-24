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
          class: "rounded-xl border " \
                 "border-[var(--ha-border)] " \
                 "bg-[var(--ha-surface)] p-5 " \
                 "transition-colors duration-150 " \
                 "hover:bg-[var(--ha-surface-hover)]") do
        render_header
        p(class: "mt-3 text-sm leading-relaxed " \
                 "text-[var(--ha-text)]") do
          plain @comment.body
        end
        render_actions
      end
    end

    private

    def render_header
      div(class: "flex items-center justify-between") do
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
        render_delete_button if can_modify?
      end
    end

    def render_delete_button
      button_to(
        "Delete",
        view_context.trip_journal_entry_comment_path(
          @trip, @entry, @comment
        ),
        method: :delete,
        class: "text-xs text-[var(--ha-danger)] " \
               "hover:text-[var(--ha-danger-strong)]",
        form: { class: "inline-flex" }
      )
    end

    def render_actions
      # Reserved for future inline actions (edit, reply)
    end

    def can_modify?
      view_context.allowed_to?(:destroy?, @comment)
    end
  end
end
