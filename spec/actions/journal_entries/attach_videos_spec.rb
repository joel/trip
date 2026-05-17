# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::AttachVideos do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "#call validation" do
    it "rejects a non-array" do
      expect(
        described_class.new.call(journal_entry: entry, urls: nil)
      ).to be_failure
    end

    it "rejects non-HTTPS URLs" do
      result = described_class.new.call(
        journal_entry: entry, urls: %w[http://example.com/a.mp4]
      )
      expect(result.failure).to match(/Only HTTPS/)
    end

    it "rejects too many URLs per call" do
      result = described_class.new.call(
        journal_entry: entry,
        urls: Array.new(4) { "https://example.com/a.mp4" }
      )
      expect(result.failure).to match(/Too many URLs/)
    end

    it "rejects exceeding the per-entry maximum" do
      create_list(:journal_entry_video, 5, journal_entry: entry)
      result = described_class.new.call(
        journal_entry: entry,
        urls: %w[https://example.com/a.mp4]
      )
      expect(result.failure).to match(/maximum of 5/)
    end
  end

  describe "#call download" do
    let(:mp4_bytes) do
      Rails.root.join("spec/fixtures/files/tiny.mp4").binread
    end

    before do
      allow(Resolv).to receive(:getaddress)
        .and_return("93.184.216.34")
      response = Net::HTTPOK.new("1.1", "200", "OK")
      allow(response).to receive_messages(content_type: "video/mp4")
      allow(response).to receive(:read_body).and_yield(mp4_bytes)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive_messages(
        "use_ssl=": nil, "open_timeout=": nil,
        "read_timeout=": nil, "verify_mode=": nil
      )
      allow(http).to receive(:request).and_yield(response)
      allow(JournalEntries::ProbeVideo).to receive(:call)
        .and_return(duration: 1.0, width: 160, height: 120)
    end

    it "creates a pending video and emits the event" do
      allow(Rails.event).to receive(:notify)

      result = described_class.new.call(
        journal_entry: entry,
        urls: %w[https://example.com/clip.mp4]
      )

      expect(result).to be_success
      video = entry.videos.reload.first
      expect(video).to be_pending
      expect(video.width).to eq(160)
      expect(video.source).to be_attached
      expect(Rails.event).to have_received(:notify).with(
        "journal_entry.videos_added",
        hash_including(journal_entry_id: entry.id, count: 1)
      )
    end
  end
end
