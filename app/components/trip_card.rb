# frozen_string_literal: true

module Components
  class TripCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:)
      @trip = trip
    end

    def view_template
      div(id: dom_id(@trip), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "text-xs font-semibold uppercase " \
                     "tracking-[0.2em] text-[var(--ha-muted)]") do
              plain "Trip"
            end
            p(class: "mt-2 text-lg font-semibold " \
                     "text-[var(--ha-text)]") do
              plain @trip.name
            end
            render_dates if @trip.effective_start_date
            render_description if @trip.description.present?
          end
          render Components::TripStateBadge.new(state: @trip.state)
        end
        render_actions
      end
    end

    private

    def render_dates
      div(class: "mt-2 text-xs text-[var(--ha-muted)]") do
        plain @trip.effective_start_date&.to_fs(:long)
        plain " — #{@trip.effective_end_date.to_fs(:long)}" if @trip.effective_end_date
      end
    end

    def render_description
      p(class: "mt-2 text-sm text-[var(--ha-muted)] " \
               "line-clamp-2") do
        plain @trip.description
      end
    end

    def render_actions
      div(class: "mt-5 flex flex-wrap gap-2") do
        link_to("View", view_context.trip_path(@trip),
                class: "ha-button ha-button-secondary")
        link_to("Edit", view_context.edit_trip_path(@trip),
                class: "ha-button ha-button-secondary")
      end
    end
  end
end
