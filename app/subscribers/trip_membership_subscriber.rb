# frozen_string_literal: true

class TripMembershipSubscriber
  def emit(event)
    case event[:name]
    when "trip_membership.created"
      SendTripAssignmentEmailJob.perform_later(
        event[:payload][:trip_membership_id]
      )
      dispatch_member_added_notification(event[:payload])
    end
  end

  private

  def dispatch_member_added_notification(payload)
    return unless payload[:actor_id]

    CreateNotificationJob.perform_later(
      notifiable_type: "TripMembership",
      notifiable_id: payload[:trip_membership_id],
      recipient_id: payload[:user_id],
      actor_id: payload[:actor_id],
      event_type: "member_added"
    )
  end
end
