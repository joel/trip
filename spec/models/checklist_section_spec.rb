# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChecklistSection do
  describe "validations" do
    it "requires name" do
      section = build(:checklist_section, name: nil)
      expect(section).not_to be_valid
      expect(section.errors[:name]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to checklist" do
      section = create(:checklist_section)
      expect(section.checklist).to be_a(Checklist)
    end

    it "has many checklist_items with dependent destroy" do
      section = create(:checklist_section)
      create(:checklist_item, checklist_section: section)
      expect(section.checklist_items.count).to eq(1)

      section.destroy!
      expect(ChecklistItem.count).to eq(0)
    end
  end
end
