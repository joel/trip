# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::DeleteComment do
  describe ".call" do
    it "deletes a comment on a writable trip" do
      trip = create(:trip, :started)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry)

      result = described_class.call(comment_id: comment.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["deleted"]).to be(true)
      expect(data["id"]).to eq(comment.id)
      expect(Comment.exists?(comment.id)).to be(false)
    end

    it "allows deletion on a finished (commentable) trip" do
      trip = create(:trip, :finished)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry)

      result = described_class.call(comment_id: comment.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["deleted"]).to be(true)
      expect(Comment.exists?(comment.id)).to be(false)
    end

    it "rejects deletion on a non-commentable trip" do
      trip = create(:trip, :archived)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry)

      result = described_class.call(comment_id: comment.id)

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not commentable")
      expect(Comment.exists?(comment.id)).to be(true)
    end

    it "returns error for a nonexistent comment" do
      result = described_class.call(comment_id: "missing")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
