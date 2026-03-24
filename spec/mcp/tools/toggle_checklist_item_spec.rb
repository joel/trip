# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ToggleChecklistItem do
  let(:item) { create(:checklist_item, completed: false) }

  describe ".call" do
    it "toggles the item to completed" do
      result = described_class.call(checklist_item_id: item.id)

      data = JSON.parse(result.content.first[:text])
      expect(data["completed"]).to be true
      expect(item.reload.completed).to be true
    end

    it "toggles back to incomplete" do
      item.update!(completed: true)

      result = described_class.call(checklist_item_id: item.id)

      data = JSON.parse(result.content.first[:text])
      expect(data["completed"]).to be false
    end

    it "rejects toggles on non-writable trips" do
      item.checklist_section.checklist.trip.update!(state: :archived)

      result = described_class.call(checklist_item_id: item.id)

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not writable")
    end

    it "returns error for nonexistent item" do
      result = described_class.call(checklist_item_id: "nonexistent")

      expect(result.error?).to be true
    end
  end
end
