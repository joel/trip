# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::UploadJournalImages do
  let(:entry) { create(:journal_entry) }
  let(:jpeg_bytes) do
    Rails.root.join("spec/fixtures/files/test_image.jpg").binread
  end
  let(:valid_b64) { Base64.strict_encode64(jpeg_bytes) }

  describe ".call" do
    before do
      allow_any_instance_of( # rubocop:disable RSpec/AnyInstance
        ActiveStorage::Attached::Many
      ).to receive(:attach).and_return(true)
    end

    it "attaches images and returns count" do
      result = described_class.call(
        journal_entry_id: entry.id,
        images: [{ data: valid_b64, filename: "photo.jpg" }]
      )

      expect(result.error?).to be false
      data = JSON.parse(result.content.first[:text])
      expect(data["attached"]).to eq(1)
      expect(data["journal_entry_id"]).to eq(entry.id)
    end

    it "rejects images on non-writable trips" do
      entry.trip.update!(state: :archived)

      result = described_class.call(
        journal_entry_id: entry.id,
        images: [{ data: valid_b64 }]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not writable")
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent",
        images: [{ data: valid_b64 }]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not found")
    end

    it "rejects invalid base64 data" do
      result = described_class.call(
        journal_entry_id: entry.id,
        images: [{ data: "not-valid!!!" }]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Invalid base64")
    end

    it "rejects too many images" do
      images = Array.new(6) { { data: valid_b64 } }

      result = described_class.call(
        journal_entry_id: entry.id, images: images
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Too many")
    end
  end
end
