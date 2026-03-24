# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::UpdateJournalEntry do
  let(:entry) { create(:journal_entry) }

  describe ".call" do
    it "updates the journal entry name" do
      result = described_class.call(
        journal_entry_id: entry.id, name: "Updated Title"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["name"]).to eq("Updated Title")
      expect(entry.reload.name).to eq("Updated Title")
    end

    it "returns error for nonexistent entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent"
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
