# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::DeleteJournalEntry do
  describe ".call" do
    it "deletes an entry on a writable trip" do
      trip = create(:trip, :started)
      entry = create(:journal_entry, trip: trip)

      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["deleted"]).to be(true)
      expect(data["id"]).to eq(entry.id)
      expect(JournalEntry.exists?(entry.id)).to be(false)
    end

    it "rejects deletion on a non-writable trip" do
      trip = create(:trip, :archived)
      entry = create(:journal_entry, trip: trip)

      result = described_class.call(journal_entry_id: entry.id)

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not writable")
      expect(JournalEntry.exists?(entry.id)).to be(true)
    end

    it "returns error for a nonexistent entry" do
      result = described_class.call(journal_entry_id: "missing")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
