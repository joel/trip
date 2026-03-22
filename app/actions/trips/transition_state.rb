# frozen_string_literal: true

module Trips
  class TransitionState < BaseAction
    def call(trip:, new_state:)
      yield validate_guard(trip, new_state.to_sym)
      from_state = trip.state
      yield transition(trip, new_state)
      yield emit_event(trip, from_state)
      Success(trip)
    end

    private

    def validate_guard(trip, new_state)
      if trip.planning? && new_state == :started &&
         trip.trip_memberships.empty?
        return Failure(:requires_members)
      end

      Success()
    end

    def transition(trip, new_state)
      trip.transition_to!(new_state)
      Success()
    rescue Trip::InvalidTransitionError => e
      Failure(e.message)
    end

    def emit_event(trip, from_state)
      Rails.event.notify(
        "trip.state_changed",
        trip_id: trip.id,
        from_state: from_state,
        to_state: trip.state
      )
      Success()
    end
  end
end
