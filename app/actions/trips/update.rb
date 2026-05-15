# frozen_string_literal: true

module Trips
  class Update < BaseAction
    def call(trip:, params:)
      yield persist(trip, params)
      yield emit_event(trip)
      Success(trip)
    end

    private

    def persist(trip, params)
      trip.update!(params)
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(trip)
      Rails.event.notify(
        "trip.updated",
        trip_id: trip.id,
        changes: trip.saved_changes.except("created_at", "updated_at")
      )
      Success()
    end
  end
end
