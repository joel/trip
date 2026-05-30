# frozen_string_literal: true

require "rails_helper"

RSpec.describe Checklists::Create do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  describe "#call" do
    it "creates a checklist with valid params" do
      result = described_class.new.call(
        params: { name: "Packing List" }, trip: trip
      )

      expect(result).to be_success
      checklist = result.value!
      expect(checklist.name).to eq("Packing List")
      expect(checklist.trip).to eq(trip)
    end

    it "returns failure with blank name" do
      result = described_class.new.call(
        params: { name: "" }, trip: trip
      )

      expect(result).to be_failure
    end
  end
end
