# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChecklistItems::Toggle do
  describe "#call" do
    it "toggles completed from false to true" do
      item = create(:checklist_item, completed: false)

      result = described_class.new.call(checklist_item: item)

      expect(result).to be_success
      expect(item.reload).to be_completed
    end

    it "toggles completed from true to false" do
      item = create(:checklist_item, completed: true)

      result = described_class.new.call(checklist_item: item)

      expect(result).to be_success
      expect(item.reload).not_to be_completed
    end
  end
end
