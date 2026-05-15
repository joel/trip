# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::CreateChecklistItem do
  describe ".call" do
    it "adds an item to a section on a writable trip" do
      trip = create(:trip, :started)
      checklist = create(:checklist, trip: trip)
      section = create(:checklist_section, checklist: checklist)

      result = described_class.call(
        checklist_section_id: section.id,
        content: "Passport", position: 1
      )
      data = JSON.parse(result.content.first[:text])

      expect(data["content"]).to eq("Passport")
      expect(data["completed"]).to be(false)
      expect(data["checklist_section_id"]).to eq(section.id)
      expect(section.checklist_items.count).to eq(1)
    end

    it "rejects creation on a non-writable trip" do
      trip = create(:trip, :archived)
      checklist = create(:checklist, trip: trip)
      section = create(:checklist_section, checklist: checklist)

      result = described_class.call(
        checklist_section_id: section.id, content: "Nope"
      )

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not writable")
    end

    it "returns a validation error for blank content" do
      trip = create(:trip, :started)
      section = create(:checklist_section,
                       checklist: create(:checklist, trip: trip))

      result = described_class.call(
        checklist_section_id: section.id, content: ""
      )

      expect(result.error?).to be(true)
    end

    it "returns error for a nonexistent section" do
      result = described_class.call(
        checklist_section_id: "missing", content: "x"
      )

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
