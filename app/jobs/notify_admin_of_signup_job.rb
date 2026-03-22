# frozen_string_literal: true

class NotifyAdminOfSignupJob < ApplicationJob
  queue_as :default

  def perform(email)
    OnboardingMailer.signup_notification(email).deliver_now
  end
end
