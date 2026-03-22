# frozen_string_literal: true

class SendInvitationForApprovedRequestJob < ApplicationJob
  queue_as :default

  def perform(access_request_id, reviewer_id)
    access_request = AccessRequest.find(access_request_id)
    reviewer = User.find(reviewer_id)

    result = Invitations::SendInvitation.new.call(
      params: { email: access_request.email },
      user: reviewer
    )

    return unless result.failure?

    Rails.logger.error("Failed to send invitation for access request #{access_request_id}: #{result.failure}")
  end
end
