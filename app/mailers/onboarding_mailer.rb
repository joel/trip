# frozen_string_literal: true

class OnboardingMailer < ApplicationMailer
  def signup_notification(email)
    @email = email
    @admin_emails = User.where("roles_mask & 1 != 0").pluck(:email)
    return if @admin_emails.empty?

    mail(
      to: @admin_emails,
      subject: "New user signed up: #{@email}"
    )
  end
end
