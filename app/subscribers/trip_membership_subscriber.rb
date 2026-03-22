# frozen_string_literal: true

class TripMembershipSubscriber
  def emit(event)
    case event[:name]
    when "trip_membership.created"
      SendTripAssignmentEmailJob.perform_later(
        event[:payload][:trip_membership_id]
      )
    end
  end
end
