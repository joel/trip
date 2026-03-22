# frozen_string_literal: true

class SendTripAssignmentEmailJob < ApplicationJob
  queue_as :default

  def perform(trip_membership_id)
    TripMailer.member_added(trip_membership_id).deliver_now
  end
end
