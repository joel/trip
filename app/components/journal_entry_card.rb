# frozen_string_literal: true

module Components
  class JournalEntryCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:, journal_entry:)
      @trip = trip
      @entry = journal_entry
    end

    def view_template
      div(id: dom_id(@entry), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "text-xs font-semibold uppercase " \
                     "tracking-[0.2em] text-[var(--ha-muted)]") do
              plain @entry.entry_date.to_fs(:long)
            end
            p(class: "mt-2 text-lg font-semibold " \
                     "text-[var(--ha-text)]") do
              plain @entry.name
            end
            render_location if @entry.location_name.present?
            render_description if @entry.description.present?
          end
        end
        render_actions
      end
    end

    private

    def render_location
      p(class: "mt-1 text-xs text-[var(--ha-muted)]") do
        plain @entry.location_name
      end
    end

    def render_description
      p(class: "mt-2 text-sm text-[var(--ha-muted)] " \
               "line-clamp-2") do
        plain @entry.description
      end
    end

    def render_actions
      div(class: "mt-5 flex flex-wrap gap-2") do
        link_to(
          "View",
          view_context.trip_journal_entry_path(@trip, @entry),
          class: "ha-button ha-button-secondary"
        )
        if view_context.allowed_to?(:edit?, @entry)
          link_to(
            "Edit",
            view_context.edit_trip_journal_entry_path(@trip, @entry),
            class: "ha-button ha-button-secondary"
          )
        end
      end
    end
  end
end
