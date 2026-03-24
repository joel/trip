# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::CreateComment do
  let(:entry) { create(:journal_entry) }

  describe ".call" do
    it "creates a comment on the journal entry" do
      result = described_class.call(
        journal_entry_id: entry.id, body: "Great photo!"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["body"]).to eq("Great photo!")
      expect(data["journal_entry_id"]).to eq(entry.id)
    end

    it "returns idempotent response for duplicate telegram_message_id" do
      first = described_class.call(
        journal_entry_id: entry.id, body: "First",
        telegram_message_id: "tg-456"
      )
      first_data = JSON.parse(first.content.first[:text])

      second = described_class.call(
        journal_entry_id: entry.id, body: "Second",
        telegram_message_id: "tg-456"
      )
      second_data = JSON.parse(second.content.first[:text])

      expect(second_data["id"]).to eq(first_data["id"])
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent", body: "Hello"
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
