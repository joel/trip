# frozen_string_literal: true

module Trips
  class Delete < BaseAction
    def call(trip:)
      trip_id = trip.id
      trip_name = trip.name
      yield destroy(trip)
      yield emit_event(trip_id, trip_name)
      Success()
    end

    private

    def destroy(trip)
      trip.destroy!
      Success()
    end

    def emit_event(trip_id, trip_name)
      Rails.event.notify(
        "trip.deleted", trip_id: trip_id, trip_name: trip_name
      )
      Success()
    end
  end
end
