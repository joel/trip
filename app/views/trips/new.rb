# frozen_string_literal: true

module Views
  module Trips
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:)
        @trip = trip
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: "Trips",
            title: "New trip",
            subtitle: "Create a new travel journal."
          )

          div(class: "ha-card p-6") do
            render Components::TripForm.new(trip: @trip)
          end

          div(class: "flex flex-wrap gap-2") do
            link_to("Back to trips", view_context.trips_path,
                    class: "ha-button ha-button-secondary")
          end
        end
      end
    end
  end
end
