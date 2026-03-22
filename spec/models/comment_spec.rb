# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comment do
  describe "validations" do
    it "requires body" do
      comment = build(:comment, body: nil)
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to journal_entry and user" do
      comment = create(:comment)
      expect(comment.journal_entry).to be_a(JournalEntry)
      expect(comment.user).to be_a(User)
    end

    it "has many reactions" do
      comment = create(:comment)
      create(:reaction, reactable: comment)
      expect(comment.reactions.count).to eq(1)
    end
  end

  describe ".chronological" do
    it "orders by created_at then id" do
      entry = create(:journal_entry)
      first = create(:comment, journal_entry: entry)
      second = create(:comment, journal_entry: entry)

      result = entry.comments.chronological
      expect(result.first).to eq(first)
      expect(result.last).to eq(second)
    end
  end
end
