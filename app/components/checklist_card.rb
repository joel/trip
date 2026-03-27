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
        h3(class: "font-headline text-lg font-bold") do
          plain @checklist.name
        end
        render_progress
        render_footer
      end
    end

    private

    def render_progress
      total = all_items.size
      completed = all_items.count(&:completed?)
      return if total.zero?

      pct = (completed.to_f / total * 100).round

      div(class: "mt-4") do
        div(class: "flex items-center justify-between " \
                   "text-xs font-medium") do
          span(class: "text-[var(--ha-on-surface-variant)]") do
            plain "#{completed}/#{total} items"
          end
          span(class: "text-[var(--ha-primary)]") do
            plain "#{pct}%"
          end
        end
        div(class: "mt-2 h-2 overflow-hidden rounded-full " \
                   "bg-[var(--ha-surface-high)]") do
          div(class: "h-full rounded-full ha-gradient-aura " \
                     "transition-all duration-500",
              style: "width: #{pct}%")
        end
      end
    end

    def render_footer
      div(class: "mt-4") do
        link_to(
          view_context.trip_checklist_path(@trip, @checklist),
          class: "inline-flex items-center gap-1 text-sm " \
                 "font-semibold text-[var(--ha-primary)]"
        ) do
          plain "View checklist \u2192"
        end
      end
    end

    def all_items
      @all_items ||= @checklist.checklist_sections
                               .flat_map(&:checklist_items)
    end
  end
end
