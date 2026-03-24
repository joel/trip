# frozen_string_literal: true

module Components
  class ChecklistItemRow < Components::Base
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:, checklist:, item:)
      @trip = trip
      @checklist = checklist
      @item = item
    end

    def view_template
      div(id: dom_id(@item),
          class: "flex items-center gap-3 rounded-lg " \
                 "bg-[var(--ha-surface)] px-4 py-3") do
        render_toggle
        render_content
        render_delete if can_modify?
      end
    end

    private

    def render_toggle
      if can_modify?
        button_to(
          view_context.toggle_trip_checklist_checklist_item_path(
            @trip, @checklist, @item
          ),
          method: :patch,
          class: "flex-shrink-0",
          form: { class: "inline-flex" }
        ) do
          render_checkbox
        end
      else
        render_checkbox
      end
    end

    def render_checkbox
      if @item.completed?
        span(class: "flex h-5 w-5 items-center justify-center " \
                    "rounded border-2 border-green-500 " \
                    "bg-green-500 text-white text-xs") { "\u2713" }
      else
        span(class: "flex h-5 w-5 rounded border-2 " \
                    "border-[var(--ha-border)]") { "" }
      end
    end

    def render_content
      css = "flex-1 text-sm text-[var(--ha-text)]"
      css += " line-through opacity-60" if @item.completed?
      span(class: css) { @item.content }
    end

    def render_delete
      button_to(
        view_context.trip_checklist_checklist_item_path(
          @trip, @checklist, @item
        ),
        method: :delete,
        class: "text-xs text-red-500 hover:text-red-700",
        form: { class: "inline-flex" }
      ) { "Remove" }
    end

    def can_modify?
      view_context.allowed_to?(:toggle?, @item)
    end
  end
end
