# frozen_string_literal: true

class ExpireInvitationsJob < ApplicationJob
  queue_as :default

  def perform
    Invitation.pending.where(expires_at: ..Time.current).find_each do |invitation|
      invitation.update!(status: :expired)
    end
  end
end
