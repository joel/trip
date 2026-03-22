# frozen_string_literal: true

class AccessRequestSubscriber
  def emit(event)
    case event[:name]
    when "access_request.submitted"
      NotifyAdminOfAccessRequestJob.perform_later(event[:payload][:access_request_id])
    end
  end
end
