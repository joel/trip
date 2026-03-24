# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::AddReaction do
  let(:entry) { create(:journal_entry) }

  describe ".call" do
    it "adds a reaction to a journal entry" do
      result = described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["action"]).to eq("added")
      expect(data["emoji"]).to eq("thumbsup")
    end

    it "removes a reaction when toggled twice" do
      described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup"
      )

      result = described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["action"]).to eq("removed")
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent", emoji: "thumbsup"
      )

      expect(result.error?).to be true
    end
  end
end
