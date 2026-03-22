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
