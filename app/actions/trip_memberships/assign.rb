# frozen_string_literal: true

module TripMemberships
  class Assign < BaseAction
    def call(params:, trip:, actor:)
      membership = yield persist(params, trip)
      yield emit_event(membership, actor)
      Success(membership)
    end

    private

    def persist(params, trip)
      membership = trip.trip_memberships.create!(params)
      Success(membership)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(membership, actor)
      Rails.event.notify(
        "trip_membership.created",
        trip_membership_id: membership.id,
        trip_id: membership.trip_id,
        user_id: membership.user_id,
        actor_id: actor.id
      )
      Success()
    end
  end
end
