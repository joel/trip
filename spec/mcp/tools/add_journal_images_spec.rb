# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::AddJournalImages do
  let(:entry) { create(:journal_entry) }
  let(:fixture_path) do
    Rails.root.join("spec/fixtures/files/test_image.jpg")
  end

  def stub_download
    allow(URI).to receive(:open) do
      io = StringIO.new(File.binread(fixture_path))
      io.define_singleton_method(:content_type) { "image/jpeg" }
      io.define_singleton_method(:size) { 1024 }
      io
    end
  end

  describe ".call" do
    before { stub_download }

    it "attaches images and returns count" do
      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be false
      data = JSON.parse(result.content.first[:text])
      expect(data["attached"]).to eq(1)
      expect(data["total_images"]).to eq(1)
      expect(data["journal_entry_id"]).to eq(entry.id)
    end

    it "rejects images on non-writable trips" do
      entry.trip.update!(state: :archived)

      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not writable")
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent",
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not found")
    end

    it "rejects non-HTTPS URLs" do
      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["http://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("HTTPS")
    end

    it "rejects too many URLs" do
      urls = (1..6).map do |i|
        "https://example.com/photo#{i}.jpg"
      end

      result = described_class.call(
        journal_entry_id: entry.id, urls: urls
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Too many")
    end

    it "handles download errors gracefully" do
      allow(URI).to receive(:open)
        .and_raise(Timeout::Error)

      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/slow.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Timeout")
    end
  end
end
