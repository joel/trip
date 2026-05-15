# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comments::Update do
  let(:comment) { create(:comment, body: "Old body") }

  it "emits comment.updated with a changes diff" do
    allow(Rails.event).to receive(:notify)

    described_class.new.call(comment: comment, params: { body: "New body" })

    expect(Rails.event).to have_received(:notify).with(
      "comment.updated",
      comment_id: comment.id,
      journal_entry_id: comment.journal_entry_id,
      changes: hash_including("body" => ["Old body", "New body"])
    )
  end

  it "returns failure with invalid params" do
    result = described_class.new.call(comment: comment, params: { body: "" })
    expect(result).to be_failure
  end
end
