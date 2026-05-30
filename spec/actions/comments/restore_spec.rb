# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comments::Restore do
  it "restores a discarded comment into the kept scope" do
    comment = create(:comment, :discarded)
    expect { described_class.new.call(comment: comment) }
      .to change { Comment.exists?(comment.id) }.from(false).to(true)
  end

  it "emits comment.restored with the captured ids" do
    comment = create(:comment, :discarded)
    allow(Rails.event).to receive(:notify)

    described_class.new.call(comment: comment)

    expect(Rails.event).to have_received(:notify).with(
      "comment.restored",
      comment_id: comment.id, journal_entry_id: comment.journal_entry_id
    )
  end
end
