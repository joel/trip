# frozen_string_literal: true

module Views
  module Trips
    class Edit < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:)
        @trip = trip
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: "Trips",
            title: "Edit trip",
            subtitle: "Update trip details."
          )

          div(class: "ha-card p-6") do
            render Components::TripForm.new(trip: @trip)
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to trip",
              view_context.trip_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
