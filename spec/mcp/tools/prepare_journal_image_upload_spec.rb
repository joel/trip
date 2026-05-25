# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::PrepareJournalImageUpload do
  let(:entry) { create(:journal_entry) }

  before do
    # In test the storage service is :test (Disk); url_for_direct_upload
    # would need Rails default_url_options[:host]. Stub at the service
    # boundary — we're testing the tool's behaviour, not Disk URL building.
    fake_svc = instance_double(ActiveStorage::Service::DiskService,
                               url_for_direct_upload: "https://test.example/put-url",
                               headers_for_direct_upload: { "Content-Type" => "image/jpeg" })
    allow_any_instance_of(ActiveStorage::Blob) # rubocop:disable RSpec/AnyInstance
      .to receive(:service).and_return(fake_svc)
  end

  def call(**overrides)
    described_class.call(journal_entry_id: entry.id,
                         filename: "img.jpg",
                         content_type: "image/jpeg",
                         byte_size: 1234,
                         checksum: "abc==", **overrides)
  end

  it "returns signed_id + put_url for valid input" do
    result = call
    expect(result.error?).to be false
    data = JSON.parse(result.content.first[:text])
    expect(data).to include("signed_id", "put_url", "headers", "expires_at")
    expect(data["put_url"]).to start_with("http")
    expect(data["headers"]).to be_a(Hash)
  end

  it "creates an ActiveStorage::Blob row with the requested metadata" do
    expect { call }.to change(ActiveStorage::Blob, :count).by(1)
    blob = ActiveStorage::Blob.last
    expect(blob.content_type).to eq("image/jpeg")
    expect(blob.filename.to_s).to eq("img.jpg")
    expect(blob.byte_size).to eq(1234)
  end

  it "rejects unsupported content_type" do
    result = call(content_type: "application/pdf")
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("Invalid content_type")
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "rejects byte_size over the cap" do
    result = call(byte_size: described_class::MAX_FILE_SIZE + 1)
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("exceeds maximum")
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "rejects when the trip is not writable" do
    entry.trip.update!(state: :archived)
    result = call
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("not writable")
  end

  it "rejects unknown journal entry" do
    result = call(journal_entry_id: "00000000-0000-0000-0000-000000000000")
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("Journal entry not found")
  end
end
