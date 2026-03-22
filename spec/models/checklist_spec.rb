# frozen_string_literal: true

require "rails_helper"

RSpec.describe Checklist do
  describe "validations" do
    it "requires name" do
      checklist = build(:checklist, name: nil)
      expect(checklist).not_to be_valid
      expect(checklist.errors[:name]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to trip" do
      checklist = create(:checklist)
      expect(checklist.trip).to be_a(Trip)
    end

    it "has many checklist_sections with dependent destroy" do
      checklist = create(:checklist)
      create(:checklist_section, checklist: checklist)
      expect(checklist.checklist_sections.count).to eq(1)

      checklist.destroy!
      expect(ChecklistSection.count).to eq(0)
    end
  end

  describe ".ordered" do
    it "orders by position then created_at" do
      trip = create(:trip)
      second = create(:checklist, trip: trip, name: "B",
                                  position: 1)
      first = create(:checklist, trip: trip, name: "A",
                                 position: 0)

      result = trip.checklists.ordered
      expect(result.first).to eq(first)
      expect(result.last).to eq(second)
    end
  end
end
