# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ListChecklists do
  let(:trip) { create(:trip, :started) }

  before do
    checklist = create(:checklist, trip: trip)
    section = create(:checklist_section, checklist: checklist)
    create(:checklist_item, checklist_section: section, content: "Passport")
    create(:checklist_item, checklist_section: section, content: "Tickets")
  end

  describe ".call" do
    it "returns checklists with sections and items" do
      result = described_class.call(trip_id: trip.id)

      data = JSON.parse(result.content.first[:text])
      expect(data["checklists"].size).to eq(1)

      sections = data["checklists"].first["sections"]
      expect(sections.size).to eq(1)

      items = sections.first["items"]
      expect(items.size).to eq(2)
      expect(items.pluck("content")).to contain_exactly(
        "Passport", "Tickets"
      )
    end
  end
end
