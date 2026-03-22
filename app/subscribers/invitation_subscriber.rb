# frozen_string_literal: true

class InvitationSubscriber
  def emit(event)
    case event[:name]
    when "invitation.sent"
      SendInvitationEmailJob.perform_later(event[:payload][:invitation_id])
    end
  end
end
