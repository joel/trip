# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def invite(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @signup_url = "#{default_url_options_base}/create-account?invitation_token=#{@invitation.token}"

    mail(
      to: @invitation.email,
      subject: "You've been invited to Trip Journal"
    )
  end

  private

  def default_url_options_base
    options = Rails.application.config.action_mailer.default_url_options || {}
    protocol = options[:protocol] || "https"
    host = options[:host] || "localhost"
    port = options[:port]
    base = "#{protocol}://#{host}"
    base += ":#{port}" if port
    base
  end
end
