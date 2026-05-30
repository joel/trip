# frozen_string_literal: true

module Trips
  class Restore < BaseAction
    def call(trip:)
      yield restore(trip)
      yield emit_event(trip)
      Success(trip)
    end

    private

    def restore(trip)
      trip.undiscard!
      Success()
    rescue Discard::RecordNotUndiscarded => e
      Failure(e.message)
    end

    def emit_event(trip)
      Rails.event.notify(
        "trip.restored", trip_id: trip.id, trip_name: trip.name
      )
      Success()
    end
  end
end
