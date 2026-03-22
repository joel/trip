# frozen_string_literal: true

class AccessRequestMailer < ApplicationMailer
  def new_request(access_request_id)
    @access_request = AccessRequest.find(access_request_id)
    @admin_emails = User.where("roles_mask & 1 != 0").pluck(:email)
    return if @admin_emails.empty?

    mail(
      to: @admin_emails,
      subject: "New access request from #{@access_request.email}"
    )
  end
end
