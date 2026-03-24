# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::GetTripStatus do
  let(:trip) { create(:trip, :started, name: "Europe Trip") }

  before do
    create(:trip_membership, trip: trip)
    create(:journal_entry, trip: trip)
    create(:checklist, trip: trip)
  end

  describe ".call" do
    it "returns trip metadata" do
      result = described_class.call(trip_id: trip.id)

      data = JSON.parse(result.content.first[:text])
      expect(data["name"]).to eq("Europe Trip")
      expect(data["state"]).to eq("started")
      expect(data["member_count"]).to eq(1)
      expect(data["entry_count"]).to eq(1)
      expect(data["checklist_count"]).to eq(1)
    end

    it "returns error when multiple trips started" do
      create(:trip, :started, name: "Second Trip")

      result = described_class.call

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("Multiple active trips")
    end
  end
end
