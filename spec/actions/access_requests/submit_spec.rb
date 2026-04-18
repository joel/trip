# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessRequests::Submit do
  describe "#call" do
    it "creates an access request with valid email" do
      result = described_class.new.call(params: { email: "test@example.com" })

      expect(result).to be_success
      expect(result.value!).to be_a(AccessRequest)
      expect(result.value!.email).to eq("test@example.com")
      expect(result.value!).to be_pending
    end

    it "returns failure with invalid email" do
      result = described_class.new.call(params: { email: "" })

      expect(result).to be_failure
    end

    it "returns failure when a pending request already exists for the email" do
      AccessRequest.create!(email: "dupe@example.com")
      result = described_class.new.call(params: { email: "dupe@example.com" })

      expect(result).to be_failure
      expect(result.failure[:email].join).to include("pending request")
    end

    it "returns failure when a User already exists with the email" do
      User.create!(email: "registered@example.com")
      result = described_class.new.call(params: { email: "registered@example.com" })

      expect(result).to be_failure
      expect(result.failure[:email].join).to include("already registered")
    end
  end
end
