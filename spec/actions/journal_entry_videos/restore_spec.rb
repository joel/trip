# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryVideos::Restore do
  it "undiscards the video back into the kept scope" do
    video = create(:journal_entry_video, :discarded)
    expect { described_class.new.call(video: video) }
      .to change { JournalEntryVideo.exists?(video.id) }.from(false).to(true)
  end

  it "emits journal_entry_video.restored with the entry + trip ids" do
    video = create(:journal_entry_video, :discarded)
    entry = video.journal_entry
    allow(Rails.event).to receive(:notify)

    described_class.new.call(video: video)

    expect(Rails.event).to have_received(:notify).with(
      "journal_entry_video.restored",
      journal_entry_video_id: video.id,
      journal_entry_id: entry.id, trip_id: entry.trip_id
    )
  end

  it "fails when the video is not discarded" do
    video = create(:journal_entry_video)
    result = described_class.new.call(video: video)
    expect(result).to be_failure
  end
end
