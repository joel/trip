# frozen_string_literal: true

module TripMemberships
  class Remove < BaseAction
    def call(membership:)
      trip_id = membership.trip_id
      user_id = membership.user_id
      membership_id = membership.id
      yield destroy(membership)
      yield emit_event(membership_id, trip_id, user_id)
      Success()
    end

    private

    def destroy(membership)
      membership.destroy!
      Success()
    end

    def emit_event(membership_id, trip_id, user_id)
      Rails.event.notify(
        "trip_membership.removed",
        trip_membership_id: membership_id,
        trip_id: trip_id,
        user_id: user_id
      )
      Success()
    end
  end
end
