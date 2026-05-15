# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ListTrips do
  describe ".call" do
    it "lists trips of any state, newest first" do
      create(:trip, name: "Planning Trip")
      create(:trip, :archived, name: "Old Trip")

      result = described_class.call
      data = JSON.parse(result.content.first[:text])

      names = data["trips"].pluck("name")
      expect(names).to contain_exactly("Planning Trip", "Old Trip")
      expect(data["total"]).to eq(2)
    end

    it "includes archived trips" do
      create(:trip, :archived, name: "Archived One")

      result = described_class.call
      data = JSON.parse(result.content.first[:text])

      states = data["trips"].pluck("state")
      expect(states).to include("archived")
    end

    it "returns member and entry counts" do
      trip = create(:trip, :started)
      create(:trip_membership, trip: trip)
      create(:journal_entry, trip: trip)

      result = described_class.call
      data = JSON.parse(result.content.first[:text])
      row = data["trips"].find { |t| t["id"] == trip.id }

      expect(row["member_count"]).to eq(1)
      expect(row["entry_count"]).to eq(1)
    end

    it "clamps limit and respects offset" do
      create_list(:trip, 3)

      result = described_class.call(limit: 1, offset: 1)
      data = JSON.parse(result.content.first[:text])

      expect(data["trips"].size).to eq(1)
      expect(data["limit"]).to eq(1)
      expect(data["offset"]).to eq(1)
      expect(data["total"]).to eq(3)
    end
  end
end
