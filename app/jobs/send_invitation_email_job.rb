# frozen_string_literal: true

class SendInvitationEmailJob < ApplicationJob
  queue_as :default

  def perform(invitation_id)
    InvitationMailer.invite(invitation_id).deliver_now
  end
end
