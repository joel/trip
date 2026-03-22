# frozen_string_literal: true

module Views
  module JournalEntries
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, journal_entry:)
        @trip = trip
        @journal_entry = journal_entry
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "New journal entry",
            subtitle: "Add an entry to your trip journal."
          )

          div(class: "ha-card p-6") do
            render Components::JournalEntryForm.new(
              trip: @trip, journal_entry: @journal_entry
            )
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to trip", view_context.trip_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
