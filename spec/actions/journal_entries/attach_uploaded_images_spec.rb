# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::AttachUploadedImages do
  let(:entry) { create(:journal_entry) }
  let(:bytes) { Rails.root.join("spec/fixtures/files/test_image.jpg").binread }

  def create_blob(content_type: "image/jpeg", byte_size: bytes.bytesize)
    # Use ActiveStorageBlobBuilder so the explicit UUID id is set
    # (active_storage_blobs.id has no DB default in this app).
    ActiveStorageBlobBuilder.upload(
      io: StringIO.new(bytes),
      filename: "test.jpg",
      content_type: content_type
    ).tap do |b|
      # update_columns lets us override content_type (the upload path
      # may identify the bytes as image/jpeg) and byte_size for the
      # boundary cases below.
      b.update_columns(content_type: content_type, byte_size: byte_size) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  it "attaches resolved blobs and emits the images_added event" do
    blob = create_blob
    events = []
    subscriber = Class.new do
      def initialize(sink) = @sink = sink
      def emit(event) = (@sink << event if event[:name] == "journal_entry.images_added")
    end.new(events)
    Rails.event.subscribe(subscriber)

    result = described_class.new.call(
      journal_entry: entry, signed_ids: [blob.signed_id]
    )

    expect(result).to be_success
    expect(entry.reload.images.count).to eq(1)
    expect(events.size).to eq(1)
    expect(events.first[:payload][:count]).to eq(1)
  end

  it "fails when signed_ids is empty" do
    result = described_class.new.call(journal_entry: entry, signed_ids: [])
    expect(result).to be_failure
    expect(result.failure).to include("non-empty")
  end

  it "fails when a signed_id is invalid" do
    result = described_class.new.call(
      journal_entry: entry, signed_ids: ["clearly-not-a-real-signed-id"]
    )
    expect(result).to be_failure
    expect(result.failure).to include("could not be found")
  end

  it "rejects unsupported content_type" do
    blob = create_blob(content_type: "application/pdf")
    result = described_class.new.call(
      journal_entry: entry, signed_ids: [blob.signed_id]
    )
    expect(result).to be_failure
    expect(result.failure).to include("Invalid image type")
    expect(entry.images.count).to eq(0)
  end

  it "rejects blobs larger than MAX_FILE_SIZE" do
    blob = create_blob(byte_size: described_class::MAX_FILE_SIZE + 1)
    result = described_class.new.call(
      journal_entry: entry, signed_ids: [blob.signed_id]
    )
    expect(result).to be_failure
    expect(result.failure).to include("too large")
  end

  it "rejects when attaching would exceed MAX_IMAGES_PER_ENTRY" do
    described_class::MAX_IMAGES_PER_ENTRY.times { entry.images.attach(create_blob) }
    blob = create_blob
    result = described_class.new.call(
      journal_entry: entry, signed_ids: [blob.signed_id]
    )
    expect(result).to be_failure
    expect(result.failure).to include("Would exceed maximum")
  end
end
