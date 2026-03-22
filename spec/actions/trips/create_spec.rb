# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trips::Create do
  let(:admin) { create(:user, :superadmin) }

  describe "#call" do
    it "creates a trip with valid params" do
      result = described_class.new.call(
        params: { name: "Road Trip" }, user: admin
      )

      expect(result).to be_success
      trip = result.value!
      expect(trip.name).to eq("Road Trip")
      expect(trip.created_by).to eq(admin)
      expect(trip).to be_planning
    end

    it "returns failure with missing name" do
      result = described_class.new.call(
        params: { name: "" }, user: admin
      )

      expect(result).to be_failure
    end
  end
end
