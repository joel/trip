# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::DeleteChecklist do
  describe ".call" do
    it "deletes a checklist on a writable trip" do
      trip = create(:trip, :started)
      checklist = create(:checklist, trip: trip)

      result = described_class.call(checklist_id: checklist.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["deleted"]).to be(true)
      expect(data["id"]).to eq(checklist.id)
      expect(Checklist.exists?(checklist.id)).to be(false)
    end

    it "rejects deletion on a non-writable trip" do
      trip = create(:trip, :archived)
      checklist = create(:checklist, trip: trip)

      result = described_class.call(checklist_id: checklist.id)

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not writable")
      expect(Checklist.exists?(checklist.id)).to be(true)
    end

    it "returns error for a nonexistent checklist" do
      result = described_class.call(checklist_id: "missing")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
