# frozen_string_literal: true

module Views
  module Checklists
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, checklist:)
        @trip = trip
        @checklist = checklist
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "New checklist",
            subtitle: "Create a checklist for your trip."
          )

          div(class: "ha-card p-6") do
            render Components::ChecklistForm.new(
              trip: @trip, checklist: @checklist
            )
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to checklists",
              view_context.trip_checklists_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
