# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChecklistItem do
  describe "validations" do
    it "requires content" do
      item = build(:checklist_item, content: nil)
      expect(item).not_to be_valid
      expect(item.errors[:content]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to checklist_section" do
      item = create(:checklist_item)
      expect(item.checklist_section).to be_a(ChecklistSection)
    end
  end

  describe "#toggle!" do
    it "flips completed from false to true" do
      item = create(:checklist_item, completed: false)
      item.toggle!
      expect(item.reload).to be_completed
    end

    it "flips completed from true to false" do
      item = create(:checklist_item, completed: true)
      item.toggle!
      expect(item.reload).not_to be_completed
    end
  end

  describe ".ordered" do
    it "orders by position then created_at" do
      section = create(:checklist_section)
      second = create(:checklist_item, checklist_section: section,
                                       content: "B", position: 1)
      first = create(:checklist_item, checklist_section: section,
                                      content: "A", position: 0)

      result = section.checklist_items.ordered
      expect(result.first).to eq(first)
      expect(result.last).to eq(second)
    end
  end
end
