# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::UpdateChecklist do
  describe ".call" do
    it "renames a checklist on a writable trip" do
      trip = create(:trip, :started)
      checklist = create(:checklist, trip: trip, name: "Old")

      result = described_class.call(
        checklist_id: checklist.id, name: "New", position: 5
      )
      data = JSON.parse(result.content.first[:text])

      expect(data["name"]).to eq("New")
      expect(data["position"]).to eq(5)
      expect(checklist.reload.name).to eq("New")
    end

    it "rejects updates on a non-writable trip" do
      trip = create(:trip, :archived)
      checklist = create(:checklist, trip: trip, name: "Old")

      result = described_class.call(
        checklist_id: checklist.id, name: "New"
      )

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not writable")
      expect(checklist.reload.name).to eq("Old")
    end

    it "errors when no updatable params are given" do
      checklist = create(:checklist, trip: create(:trip, :started))

      result = described_class.call(checklist_id: checklist.id)

      expect(result.error?).to be(true)
      expect(result.content.first[:text])
        .to include("No updatable parameters")
    end

    it "returns error for a nonexistent checklist" do
      result = described_class.call(checklist_id: "missing", name: "x")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
