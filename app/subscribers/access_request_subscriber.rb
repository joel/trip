# frozen_string_literal: true

class AccessRequestSubscriber
  def emit(event)
    case event[:name]
    when "access_request.submitted"
      NotifyAdminOfAccessRequestJob.perform_later(event[:payload][:access_request_id])
    when "access_request.approved"
      SendInvitationForApprovedRequestJob.perform_later(
        event[:payload][:access_request_id],
        event[:payload][:reviewer_id]
      )
    end
  end
end
