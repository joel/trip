# frozen_string_literal: true

module Views
  module Checklists
    class Edit < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, checklist:)
        @trip = trip
        @checklist = checklist
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "Edit checklist"
          )

          div(class: "ha-card p-6") do
            render Components::ChecklistForm.new(
              trip: @trip, checklist: @checklist
            )
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to checklist",
              view_context.trip_checklist_path(
                @trip, @checklist
              ),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
