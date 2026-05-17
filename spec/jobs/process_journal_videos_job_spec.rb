# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessJournalVideosJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  it "transcodes a pending video to ready with web + poster" do
    video = create(:journal_entry_video, journal_entry: entry,
                                         status: :pending)

    described_class.perform_now(entry.id)

    video.reload
    expect(video).to be_ready
    expect(video.web).to be_attached
    expect(video.poster).to be_attached
    expect(video.duration).to be_within(0.3).of(1.0)
    expect(video.width).to eq(160)
  end

  it "is idempotent — only processes pending videos" do
    ready = create(:journal_entry_video, :ready, journal_entry: entry)
    original_web = ready.web.blob.id
    create(:journal_entry_video, journal_entry: entry,
                                 status: :pending)

    described_class.perform_now(entry.id)

    expect(ready.reload.web.blob.id).to eq(original_web)
    expect(entry.videos.where(status: :ready).count).to eq(2)
  end

  it "marks the video failed without raising on a bad source" do
    video = create(:journal_entry_video, journal_entry: entry,
                                         status: :pending)
    video.source.attach(
      ActiveStorageBlobBuilder.upload(
        io: StringIO.new("not a video"),
        filename: "broken.mp4", content_type: "video/mp4"
      )
    )

    expect do
      described_class.perform_now(entry.id)
    end.not_to raise_error

    video.reload
    expect(video).to be_failed
    expect(video.error_message).to be_present
  end
end
