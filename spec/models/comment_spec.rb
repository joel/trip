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

  describe "soft deletion (discard)" do
    it "discard sets discarded_at and marks the record discarded" do
      comment = create(:comment)
      expect { comment.discard! }
        .to change(comment, :discarded?).from(false).to(true)
      expect(comment.discarded_at).to be_present
    end

    it "default scope hides discarded comments but with_discarded sees them" do
      comment = create(:comment, :discarded)
      expect(described_class.exists?(comment.id)).to be(false)
      expect(described_class.with_discarded.exists?(comment.id)).to be(true)
      expect(described_class.discarded).to be_empty
      expect(described_class.with_discarded.discarded).to include(comment)
    end

    it "is excluded from its entry's comments association once discarded" do
      entry = create(:journal_entry)
      kept = create(:comment, journal_entry: entry)
      create(:comment, :discarded, journal_entry: entry)
      expect(entry.comments).to contain_exactly(kept)
    end

    it "undiscard restores it into the kept scope" do
      comment = create(:comment, :discarded)
      comment.undiscard!
      expect(described_class.exists?(comment.id)).to be(true)
    end
  end
end
