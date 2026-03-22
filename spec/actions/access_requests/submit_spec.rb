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
  end
end
