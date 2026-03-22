# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitation do
  let(:inviter) { create(:user, :superadmin) }

  describe "validations" do
    it "requires email" do
      inv = described_class.new(inviter: inviter, expires_at: 7.days.from_now, email: nil)
      expect(inv).not_to be_valid
      expect(inv.errors[:email]).to include("can't be blank")
    end

    it "requires expires_at" do
      inv = described_class.new(inviter: inviter, email: "a@b.com", expires_at: nil)
      expect(inv).not_to be_valid
      expect(inv.errors[:expires_at]).to include("can't be blank")
    end
  end

  describe "token generation" do
    it "generates a token on create" do
      inv = described_class.create!(inviter: inviter, email: "a@b.com", expires_at: 7.days.from_now)
      expect(inv.token).to be_present
    end
  end

  describe "#expired?" do
    it "returns true when past expires_at" do
      inv = build(:invitation, inviter: inviter, expires_at: 1.day.ago)
      expect(inv).to be_expired
    end

    it "returns false when before expires_at" do
      inv = build(:invitation, inviter: inviter, expires_at: 1.day.from_now)
      expect(inv).not_to be_expired
    end
  end

  describe "#accept!" do
    it "marks as accepted with timestamp" do
      inv = create(:invitation, inviter: inviter)
      inv.accept!

      expect(inv).to be_accepted
      expect(inv.accepted_at).to be_present
    end
  end

  describe "scopes" do
    it ".valid_tokens returns pending non-expired invitations" do
      valid = create(:invitation, inviter: inviter)
      expired = create(:invitation, :expired_token, inviter: inviter)
      accepted = create(:invitation, :accepted, inviter: inviter)

      expect(described_class.valid_tokens).to include(valid)
      expect(described_class.valid_tokens).not_to include(expired)
      expect(described_class.valid_tokens).not_to include(accepted)
    end
  end
end
