# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::UpdateComment do
  describe ".call" do
    it "updates the comment body on a writable trip" do
      trip = create(:trip, :started)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry, body: "Old")

      result = described_class.call(comment_id: comment.id, body: "New")
      data = JSON.parse(result.content.first[:text])

      expect(data["body"]).to eq("New")
      expect(data["journal_entry_id"]).to eq(entry.id)
      expect(comment.reload.body).to eq("New")
    end

    it "allows edits on a finished (commentable) trip" do
      trip = create(:trip, :finished)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry, body: "Old")

      result = described_class.call(comment_id: comment.id, body: "New")
      data = JSON.parse(result.content.first[:text])

      expect(data["body"]).to eq("New")
      expect(comment.reload.body).to eq("New")
    end

    it "rejects edits on a non-commentable trip" do
      trip = create(:trip, :archived)
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry, body: "Old")

      result = described_class.call(comment_id: comment.id, body: "New")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not commentable")
      expect(comment.reload.body).to eq("Old")
    end

    it "returns a validation error for a blank body" do
      comment = create(:comment)

      result = described_class.call(comment_id: comment.id, body: "")

      expect(result.error?).to be(true)
    end

    it "returns error for a nonexistent comment" do
      result = described_class.call(comment_id: "missing", body: "x")

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
