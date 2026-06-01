# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryVideos::Delete do
  it "discards the video out of the kept scope" do
    video = create(:journal_entry_video)
    expect { described_class.new.call(video: video) }
      .to change { JournalEntryVideo.exists?(video.id) }.from(true).to(false)
    expect(JournalEntryVideo.with_discarded.find(video.id).discarded?).to be(true)
  end

  it "retains the source blob (no purge)" do
    video = create(:journal_entry_video)
    blob_id = video.source.blob.id
    described_class.new.call(video: video)
    expect(ActiveStorage::Blob.exists?(blob_id)).to be(true)
  end

  it "emits journal_entry_video.removed with the entry + trip ids" do
    video = create(:journal_entry_video)
    entry = video.journal_entry
    allow(Rails.event).to receive(:notify)

    described_class.new.call(video: video)

    expect(Rails.event).to have_received(:notify).with(
      "journal_entry_video.removed",
      journal_entry_video_id: video.id,
      journal_entry_id: entry.id, trip_id: entry.trip_id
    )
  end
end
