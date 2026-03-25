# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::UploadImages do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  let(:jpeg_bytes) do
    Rails.root.join("spec/fixtures/files/test_image.jpg").binread
  end
  let(:valid_b64) { Base64.strict_encode64(jpeg_bytes) }

  let(:valid_images) do
    [
      { data: valid_b64, filename: "beach.jpg" },
      { data: valid_b64 }
    ]
  end

  before do
    allow(entry.images).to receive(:attach).and_return(true)
  end

  describe "#call" do
    it "attaches images from valid base64 data" do
      result = described_class.new.call(
        journal_entry: entry, images: valid_images
      )

      expect(result).to be_success
      expect(entry.images).to have_received(:attach).twice
    end

    it "uses provided filename when given" do
      result = described_class.new.call(
        journal_entry: entry,
        images: [{ data: valid_b64, filename: "beach.jpg" }]
      )

      expect(result).to be_success
      attach_args = nil
      allow(entry.images).to receive(:attach) do |arg|
        attach_args = arg
      end
      # Re-run to capture
      described_class.new.call(
        journal_entry: entry,
        images: [{ data: valid_b64, filename: "beach.jpg" }]
      )
      expect(attach_args[:filename]).to eq("beach.jpg")
    end

    it "generates filename from MIME when not provided" do
      attach_args = nil
      allow(entry.images).to receive(:attach) do |arg|
        attach_args = arg
      end

      described_class.new.call(
        journal_entry: entry,
        images: [{ data: valid_b64 }]
      )

      expect(attach_args[:filename]).to eq("image_0.jpg")
    end

    it "normalizes string keys to symbols" do
      result = described_class.new.call(
        journal_entry: entry,
        images: [{ "data" => valid_b64, "filename" => "pic.jpg" }]
      )

      expect(result).to be_success
    end

    it "emits journal_entry.images_added event" do
      allow(Rails.event).to receive(:notify)

      described_class.new.call(
        journal_entry: entry, images: valid_images
      )

      expect(Rails.event).to have_received(:notify).with(
        "journal_entry.images_added",
        journal_entry_id: entry.id,
        trip_id: entry.trip_id,
        count: 2
      )
    end

    context "with invalid input" do
      it "rejects empty array" do
        result = described_class.new.call(
          journal_entry: entry, images: []
        )
        expect(result).to be_failure
        expect(result.failure).to include("non-empty")
      end

      it "rejects more than 5 images" do
        images = Array.new(6) { { data: valid_b64 } }
        result = described_class.new.call(
          journal_entry: entry, images: images
        )
        expect(result).to be_failure
        expect(result.failure).to include("Too many")
      end

      it "rejects when total would exceed 20" do
        allow(entry.images).to receive(:count).and_return(19)

        result = described_class.new.call(
          journal_entry: entry,
          images: [{ data: valid_b64 }, { data: valid_b64 }]
        )
        expect(result).to be_failure
        expect(result.failure).to include("exceed maximum")
      end

      it "rejects oversized encoded data before decoding" do
        huge_b64 = "A" * (described_class::MAX_ENCODED_SIZE + 1)
        result = described_class.new.call(
          journal_entry: entry,
          images: [{ data: huge_b64 }]
        )
        expect(result).to be_failure
        expect(result.failure).to include("encoded size exceeds limit")
      end

      it "rejects invalid base64 data" do
        result = described_class.new.call(
          journal_entry: entry,
          images: [{ data: "not-valid-base64!!!" }]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Invalid base64")
      end

      it "rejects non-image content type" do
        html = Base64.strict_encode64("<html>hello</html>")
        result = described_class.new.call(
          journal_entry: entry,
          images: [{ data: html }]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Invalid content type")
      end

      it "rejects oversized files" do
        huge = Base64.strict_encode64(jpeg_bytes + ("\x00" * 11.megabytes))
        result = described_class.new.call(
          journal_entry: entry,
          images: [{ data: huge }]
        )
        expect(result).to be_failure
        expect(result.failure).to include("too large")
      end
    end
  end
end
