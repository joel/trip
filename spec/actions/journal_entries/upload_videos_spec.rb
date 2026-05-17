# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::UploadVideos do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  let(:mp4_bytes) do
    Rails.root.join("spec/fixtures/files/tiny.mp4").binread
  end
  let(:valid_b64) { Base64.strict_encode64(mp4_bytes) }
  let(:valid_videos) { [{ data: valid_b64, filename: "clip.mp4" }] }

  describe "#call" do
    it "creates a pending JournalEntryVideo and emits the event" do
      allow(Rails.event).to receive(:notify)

      result = described_class.new.call(
        journal_entry: entry, videos: valid_videos
      )

      expect(result).to be_success
      video = entry.videos.reload.first
      expect(video).to be_pending
      expect(video.duration).to be_within(0.2).of(1.0)
      expect(video.width).to eq(160)
      expect(video.source).to be_attached
      expect(Rails.event).to have_received(:notify).with(
        "journal_entry.videos_added",
        hash_including(journal_entry_id: entry.id, count: 1)
      )
    end

    it "rejects an empty array" do
      result = described_class.new.call(journal_entry: entry, videos: [])
      expect(result).to be_failure
    end

    it "rejects too many videos per call" do
      result = described_class.new.call(
        journal_entry: entry,
        videos: Array.new(3) { { data: valid_b64 } }
      )
      expect(result.failure).to match(/Too many videos/)
    end

    it "rejects exceeding the per-entry maximum" do
      create_list(:journal_entry_video, 5, journal_entry: entry)
      result = described_class.new.call(
        journal_entry: entry, videos: valid_videos
      )
      expect(result.failure).to match(/maximum of 5/)
    end

    it "rejects a non-video content type" do
      jpeg = Rails.root.join("spec/fixtures/files/test_image.jpg")
                  .binread
      result = described_class.new.call(
        journal_entry: entry,
        videos: [{ data: Base64.strict_encode64(jpeg) }]
      )
      expect(result.failure).to match(/Invalid content type/)
    end
  end
end
