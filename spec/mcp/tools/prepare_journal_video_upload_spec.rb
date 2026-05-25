# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::PrepareJournalVideoUpload do
  let(:entry) { create(:journal_entry) }

  before do
    fake_svc = instance_double(ActiveStorage::Service::DiskService,
                               url_for_direct_upload: "https://test.example/put-url",
                               headers_for_direct_upload: { "Content-Type" => "video/mp4" })
    allow_any_instance_of(ActiveStorage::Blob) # rubocop:disable RSpec/AnyInstance
      .to receive(:service).and_return(fake_svc)
  end

  def call(**overrides)
    described_class.call(journal_entry_id: entry.id,
                         filename: "clip.mp4",
                         content_type: "video/mp4",
                         byte_size: 1234,
                         checksum: "abc==", **overrides)
  end

  it "returns signed_id + put_url for valid input" do
    result = call
    expect(result.error?).to be false
    data = JSON.parse(result.content.first[:text])
    expect(data).to include("signed_id", "put_url", "headers", "expires_at")
  end

  it "creates an ActiveStorage::Blob with video metadata" do
    expect { call }.to change(ActiveStorage::Blob, :count).by(1)
    blob = ActiveStorage::Blob.last
    expect(blob.content_type).to eq("video/mp4")
  end

  it "rejects non-video content_type" do
    result = call(content_type: "image/jpeg")
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("Invalid content_type")
  end

  it "rejects byte_size over the 1GB cap" do
    result = call(byte_size: described_class::MAX_FILE_SIZE + 1)
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("exceeds maximum")
  end

  it "rejects when the trip is not writable" do
    entry.trip.update!(state: :archived)
    result = call
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("not writable")
  end
end
