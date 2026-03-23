# frozen_string_literal: true

class NotifyTripStateChangeJob < ApplicationJob
  queue_as :default

  def perform(trip_id, from_state, to_state)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    trip.members.find_each do |member|
      TripMailer.state_changed(
        trip.id, member.id, from_state, to_state
      ).deliver_now
    end
  end
end
