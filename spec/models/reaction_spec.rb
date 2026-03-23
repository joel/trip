# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reaction do
  describe "validations" do
    it "requires emoji" do
      reaction = build(:reaction, emoji: nil)
      expect(reaction).not_to be_valid
      expect(reaction.errors[:emoji]).to include("can't be blank")
    end

    it "rejects emojis outside the allowed set" do
      reaction = build(:reaction, emoji: "wave")
      expect(reaction).not_to be_valid
      expect(reaction.errors[:emoji])
        .to include("is not included in the list")
    end

    it "enforces uniqueness per user, emoji, and reactable" do
      entry = create(:journal_entry)
      user = create(:user)
      create(:reaction, reactable: entry, user: user,
                        emoji: "thumbsup")
      duplicate = build(:reaction, reactable: entry, user: user,
                                   emoji: "thumbsup")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:emoji])
        .to include("has already been taken")
    end

    it "allows different emojis on same reactable by same user" do
      entry = create(:journal_entry)
      user = create(:user)
      create(:reaction, reactable: entry, user: user,
                        emoji: "thumbsup")
      other = build(:reaction, reactable: entry, user: user,
                               emoji: "heart")
      expect(other).to be_valid
    end
  end

  describe "associations" do
    it "belongs to reactable (polymorphic) and user" do
      reaction = create(:reaction)
      expect(reaction.reactable).to be_a(JournalEntry)
      expect(reaction.user).to be_a(User)
    end
  end

  describe "#trip" do
    it "resolves trip from JournalEntry reactable" do
      entry = create(:journal_entry)
      reaction = create(:reaction, reactable: entry)
      expect(reaction.trip).to eq(entry.trip)
    end

    it "resolves trip from Trip reactable" do
      trip = create(:trip)
      reaction = create(:reaction, reactable: trip)
      expect(reaction.trip).to eq(trip)
    end

    it "resolves trip from Comment reactable" do
      comment = create(:comment)
      reaction = create(:reaction, reactable: comment)
      expect(reaction.trip).to eq(comment.journal_entry.trip)
    end
  end
end
