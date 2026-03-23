# frozen_string_literal: true

module Components
  class ChecklistCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    def initialize(trip:, checklist:)
      @trip = trip
      @checklist = checklist
    end

    def view_template
      div(class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "text-lg font-semibold " \
                     "text-[var(--ha-text)]") do
              plain @checklist.name
            end
            render_progress
          end
        end
        render_actions
      end
    end

    private

    def render_progress
      total = all_items.size
      completed = all_items.count(&:completed?)
      return if total.zero?

      p(class: "mt-1 text-sm text-[var(--ha-muted)]") do
        plain "#{completed}/#{total} items completed"
      end
    end

    def render_actions
      div(class: "ha-card-actions") do
        link_to(
          "View",
          view_context.trip_checklist_path(@trip, @checklist),
          class: "ha-button ha-button-secondary"
        )
      end
    end

    def all_items
      @all_items ||= @checklist.checklist_sections
                               .flat_map(&:checklist_items)
    end
  end
end
