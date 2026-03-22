# frozen_string_literal: true

module Invitations
  class SendInvitation < BaseAction
    def call(params:, user:)
      invitation = yield persist(params, user)
      yield emit_event(invitation)
      Success(invitation)
    end

    private

    def persist(params, user)
      invitation = Invitation.create!(
        inviter: user,
        email: params[:email],
        expires_at: 7.days.from_now
      )
      Success(invitation)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(invitation)
      Rails.event.notify("invitation.sent",
                         invitation_id: invitation.id, email: invitation.email)
      Success()
    end
  end
end
