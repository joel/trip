# frozen_string_literal: true

class OnboardingSubscriber
  def emit(event)
    case event[:name]
    when "invitation.accepted"
      NotifyAdminOfSignupJob.perform_later(event[:payload][:email])
    end
  end
end
