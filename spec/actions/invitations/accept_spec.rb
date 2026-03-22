# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitations::Accept do
  let(:invitation) { create(:invitation) }

  describe "#call" do
    it "accepts a valid invitation" do
      result = described_class.new.call(token: invitation.token)

      expect(result).to be_success
      expect(invitation.reload).to be_accepted
      expect(invitation.accepted_at).to be_present
    end

    it "returns failure for unknown token" do
      result = described_class.new.call(token: "nonexistent")

      expect(result).to be_failure
      expect(result.failure).to eq(:not_found)
    end

    it "returns failure for expired invitation" do
      expired = create(:invitation, :expired_token)
      result = described_class.new.call(token: expired.token)

      expect(result).to be_failure
      expect(result.failure).to eq(:not_found)
    end

    it "returns failure for already accepted invitation" do
      accepted = create(:invitation, :accepted)
      result = described_class.new.call(token: accepted.token)

      expect(result).to be_failure
      expect(result.failure).to eq(:not_found)
    end
  end
end
