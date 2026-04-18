# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessRequest do
  describe "validations" do
    it "requires email" do
      ar = described_class.new(email: nil)
      expect(ar).not_to be_valid
      expect(ar.errors[:email]).to include("can't be blank")
    end

    it "validates email format" do
      ar = described_class.new(email: "not-an-email")
      expect(ar).not_to be_valid
      expect(ar.errors[:email]).to include("is invalid")
    end

    it "accepts valid email" do
      ar = described_class.new(email: "test@example.com")
      expect(ar).to be_valid
    end

    it "blocks a duplicate email while a pending request exists" do
      described_class.create!(email: "dupe@example.com")
      ar = described_class.new(email: "dupe@example.com")

      expect(ar).not_to be_valid
      expect(ar.errors[:email].join).to include("pending request")
    end

    it "blocks a new request when an approved one already exists" do
      described_class.create!(email: "approved@example.com", status: :approved)
      ar = described_class.new(email: "approved@example.com")

      expect(ar).not_to be_valid
      expect(ar.errors[:email].join).to include("approved invitation")
    end

    it "allows a new request when the prior one was rejected" do
      described_class.create!(email: "retry@example.com", status: :rejected)
      ar = described_class.new(email: "retry@example.com")

      expect(ar).to be_valid
    end

    it "blocks a request when the email already belongs to a User" do
      User.create!(email: "registered@example.com")
      ar = described_class.new(email: "registered@example.com")

      expect(ar).not_to be_valid
      expect(ar.errors[:email].join).to include("already registered")
    end

    it "lets a superadmin approve an existing request even after the invitee has an account" do
      ar = described_class.create!(email: "later-user@example.com")
      User.create!(email: "later-user@example.com")

      expect { ar.update!(status: :approved, reviewed_at: Time.current) }.not_to raise_error
    end

    it "lets a superadmin reject an existing request even after the invitee has an account" do
      ar = described_class.create!(email: "reject-later@example.com")
      User.create!(email: "reject-later@example.com")

      expect { ar.update!(status: :rejected, reviewed_at: Time.current) }.not_to raise_error
    end
  end

  describe "defaults" do
    it "defaults to pending status" do
      ar = described_class.create!(email: "test@example.com")
      expect(ar).to be_pending
    end
  end

  describe "scopes" do
    it ".pending returns only pending requests" do
      pending_ar = described_class.create!(email: "pending@example.com")
      approved_ar = described_class.create!(email: "approved@example.com", status: :approved)

      expect(described_class.pending).to include(pending_ar)
      expect(described_class.pending).not_to include(approved_ar)
    end
  end

  describe "associations" do
    it "belongs to reviewed_by (optional)" do
      ar = described_class.create!(email: "test@example.com")
      expect(ar.reviewed_by).to be_nil
    end
  end
end
