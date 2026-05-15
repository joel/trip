# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::CreateChecklist do
  describe ".call" do
    it "creates a checklist on a writable trip" do
      trip = create(:trip, :started)

      result = described_class.call(
        trip_id: trip.id, name: "Packing", position: 2
      )
      data = JSON.parse(result.content.first[:text])

      expect(data["name"]).to eq("Packing")
      expect(data["trip_id"]).to eq(trip.id)
      expect(data["position"]).to eq(2)
      expect(trip.checklists.count).to eq(1)
    end

    it "resolves the started trip when trip_id is omitted" do
      create(:trip, :started)

      result = described_class.call(name: "Default")
      data = JSON.parse(result.content.first[:text])

      expect(data["name"]).to eq("Default")
    end

    it "rejects creation on a non-writable trip" do
      trip = create(:trip, :archived)

      result = described_class.call(trip_id: trip.id, name: "Nope")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not writable")
    end

    it "returns a validation error for a blank name" do
      trip = create(:trip, :started)

      result = described_class.call(trip_id: trip.id, name: "")

      expect(result.error?).to be(true)
    end
  end
end
