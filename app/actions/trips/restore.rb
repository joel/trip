# frozen_string_literal: true

module Trips
  # Restores a soft-deleted trip: undiscards it into the kept scope and emits
  # "trip.restored". Restore is parent-only by design — it mirrors the down-only
  # discard cascade, so a trip's previously discarded entries are not
  # auto-resurrected. Load the trip via `Trip.with_discarded` first (the default
  # kept scope hides it). Returns Failure(message) if it is not discarded.
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
