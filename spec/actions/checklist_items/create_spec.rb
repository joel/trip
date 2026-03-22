# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChecklistItems::Create do
  let(:section) { create(:checklist_section) }

  describe "#call" do
    it "creates an item with valid params" do
      result = described_class.new.call(
        params: { content: "Passport" },
        checklist_section: section
      )

      expect(result).to be_success
      item = result.value!
      expect(item.content).to eq("Passport")
      expect(item.checklist_section).to eq(section)
    end

    it "returns failure with blank content" do
      result = described_class.new.call(
        params: { content: "" },
        checklist_section: section
      )

      expect(result).to be_failure
    end
  end
end
