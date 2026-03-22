# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessRequests::Reject do
  let(:admin) { create(:user, :superadmin) }
  let(:access_request) { create(:access_request) }

  describe "#call" do
    it "rejects the access request" do
      result = described_class.new.call(access_request: access_request, user: admin)

      expect(result).to be_success
      expect(access_request.reload).to be_rejected
      expect(access_request.reviewed_by).to eq(admin)
      expect(access_request.reviewed_at).to be_present
    end
  end
end
