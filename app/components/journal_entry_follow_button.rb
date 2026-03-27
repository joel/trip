# frozen_string_literal: true

module Components
  class JournalEntryFollowButton < Components::Base
    include Phlex::Rails::Helpers::ButtonTo

    def initialize(trip:, journal_entry:, subscribed:)
      @trip = trip
      @journal_entry = journal_entry
      @subscribed = subscribed
    end

    def view_template
      if @subscribed
        button_to(
          "Following",
          view_context.trip_journal_entry_subscription_path(
            @trip, @journal_entry
          ),
          method: :delete,
          class: "ha-button ha-button-secondary"
        )
      else
        button_to(
          "Follow",
          view_context.trip_journal_entry_subscription_path(
            @trip, @journal_entry
          ),
          method: :post,
          class: "ha-button ha-button-secondary"
        )
      end
    end
  end
end
