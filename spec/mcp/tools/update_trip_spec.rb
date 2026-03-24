# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::UpdateTrip do
  let!(:trip) { create(:trip, :started, name: "Original") }

  describe ".call" do
    it "updates the trip name" do
      result = described_class.call(
        trip_id: trip.id, name: "Updated Name"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["name"]).to eq("Updated Name")
      expect(trip.reload.name).to eq("Updated Name")
    end

    it "rejects updates on non-writable trips" do
      trip.update!(state: :archived)

      result = described_class.call(
        trip_id: trip.id, name: "Should fail"
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not writable")
    end

    it "resolves active trip when trip_id is omitted" do
      result = described_class.call(name: "Auto-resolved")

      data = JSON.parse(result.content.first[:text])
      expect(data["id"]).to eq(trip.id)
    end
  end
end
