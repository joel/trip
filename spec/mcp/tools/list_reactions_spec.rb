# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ListReactions do
  let(:entry) { create(:journal_entry) }

  describe ".call" do
    it "lists reactions with emoji and reacting user" do
      reactor = create(:user, name: "Bob", email: "bob@example.com")
      create(:reaction, reactable: entry, user: reactor,
                        emoji: "heart")

      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])
      row = data["reactions"].first

      expect(row["emoji"]).to eq("heart")
      expect(row["user_email"]).to eq("bob@example.com")
      expect(row["user_name"]).to eq("Bob")
      expect(data["total"]).to eq(1)
    end

    it "returns an empty list when there are no reactions" do
      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["reactions"]).to eq([])
      expect(data["total"]).to eq(0)
    end

    it "returns error for a nonexistent journal entry" do
      result = described_class.call(journal_entry_id: "missing")

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
