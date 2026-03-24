# frozen_string_literal: true

module Components
  class CommentForm < Components::Base
    include Phlex::Rails::Helpers::FormWith

    def initialize(trip:, journal_entry:, comment:)
      @trip = trip
      @entry = journal_entry
      @comment = comment
    end

    def view_template
      div(id: "comment_form_#{@entry.id}") do
        form_with(
          model: [@trip, @entry, @comment],
          class: "flex gap-3"
        ) do |form|
          div(class: "flex-1") do
            form.label(
              :body, "Add a comment",
              class: "sr-only"
            )
            form.text_area(
              :body,
              placeholder: "Add a comment...",
              rows: 2,
              class: "ha-input w-full text-sm"
            )
          end
          div(class: "flex items-end") do
            form.submit "Post",
                        class: "ha-button ha-button-primary text-sm"
          end
        end
      end
    end
  end
end
