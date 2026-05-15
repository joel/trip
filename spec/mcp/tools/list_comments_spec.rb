# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ListComments do
  let(:entry) { create(:journal_entry) }

  describe ".call" do
    it "lists comments chronologically with author email and name" do
      author = create(:user, name: "Jane Doe", email: "jane@example.com")
      create(:comment, journal_entry: entry, user: author,
                       body: "First!")

      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])
      row = data["comments"].first

      expect(row["body"]).to eq("First!")
      expect(row["author_email"]).to eq("jane@example.com")
      expect(row["author_name"]).to eq("Jane Doe")
      expect(data["total"]).to eq(1)
    end

    it "paginates with clamped limit and offset" do
      create_list(:comment, 3, journal_entry: entry)

      result = described_class.call(
        journal_entry_id: entry.id, limit: 1, offset: 1
      )
      data = JSON.parse(result.content.first[:text])

      expect(data["comments"].size).to eq(1)
      expect(data["limit"]).to eq(1)
      expect(data["offset"]).to eq(1)
      expect(data["total"]).to eq(3)
    end

    it "returns error for a nonexistent journal entry" do
      result = described_class.call(journal_entry_id: "missing")

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
