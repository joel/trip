# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitations::SendInvitation do
  let(:admin) { create(:user, :superadmin) }

  describe "#call" do
    it "creates an invitation with valid email" do
      result = described_class.new.call(params: { email: "invitee@example.com" }, user: admin)

      expect(result).to be_success
      invitation = result.value!
      expect(invitation.email).to eq("invitee@example.com")
      expect(invitation.inviter).to eq(admin)
      expect(invitation.token).to be_present
      expect(invitation.expires_at).to be > Time.current
    end

    it "returns failure with invalid email" do
      result = described_class.new.call(params: { email: "" }, user: admin)

      expect(result).to be_failure
    end
  end
end
