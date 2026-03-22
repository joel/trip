# frozen_string_literal: true

module Trips
  class Create < BaseAction
    def call(params:, user:)
      trip = yield persist(params, user)
      yield emit_event(trip)
      Success(trip)
    end

    private

    def persist(params, user)
      trip = Trip.create!(params.merge(created_by: user))
      Success(trip)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(trip)
      Rails.event.notify("trip.created", trip_id: trip.id)
      Success()
    end
  end
end
