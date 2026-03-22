# frozen_string_literal: true

module Invitations
  class Accept < BaseAction
    def call(token:, email: nil)
      invitation = yield find_invitation(token)
      yield verify_email(invitation, email) if email
      yield accept_invitation(invitation)
      yield emit_event(invitation)
      Success(invitation)
    end

    private

    def find_invitation(token)
      invitation = Invitation.valid_tokens.find_by(token: token)
      return Failure(:not_found) unless invitation

      Success(invitation)
    end

    def verify_email(invitation, email)
      return Success() if invitation.email.downcase == email.downcase

      Failure(:email_mismatch)
    end

    def accept_invitation(invitation)
      invitation.accept!
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(invitation)
      Rails.event.notify("invitation.accepted",
                         invitation_id: invitation.id, email: invitation.email)
      Success()
    end
  end
end
