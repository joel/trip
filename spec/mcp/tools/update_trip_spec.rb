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

    it "resolves active trip when trip_id is omitted" do
      result = described_class.call(name: "Auto-resolved")

      data = JSON.parse(result.content.first[:text])
      expect(data["id"]).to eq(trip.id)
    end
  end
end
