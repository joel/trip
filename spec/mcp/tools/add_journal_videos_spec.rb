# frozen_string_literal: true

require "rails_helper"

# URL path is covered indirectly via the videos integration tests;
# this spec focuses on the new signed_ids branch from #172.
RSpec.describe Tools::AddJournalVideos do
  let(:entry) { create(:journal_entry) }

  # A real tiny mp4 fixture so blob.content_type lines up with the
  # AttachUploadedVideos whitelist.
  let(:video_bytes) { Rails.root.join("spec/fixtures/files/tiny.mp4").binread }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(video_bytes),
      filename: "tiny.mp4",
      content_type: "video/mp4"
    )
  end

  it "attaches via signed_ids" do
    result = described_class.call(
      journal_entry_id: entry.id, signed_ids: [blob.signed_id]
    )
    expect(result.error?).to be false
    data = JSON.parse(result.content.first[:text])
    expect(data["attached"]).to eq(1)
    expect(entry.reload.videos.count).to eq(1)
  end

  it "rejects when both urls and signed_ids are provided" do
    result = described_class.call(
      journal_entry_id: entry.id,
      urls: ["https://example.com/clip.mp4"],
      signed_ids: [blob.signed_id]
    )
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("exactly one")
  end

  it "rejects when neither urls nor signed_ids are provided" do
    result = described_class.call(journal_entry_id: entry.id)
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("either urls or signed_ids")
  end

  it "rejects invalid signed_ids" do
    result = described_class.call(
      journal_entry_id: entry.id, signed_ids: ["not-a-real-signed-id"]
    )
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("could not be found")
  end

  it "rejects when the trip is not writable" do
    entry.trip.update!(state: :archived)
    result = described_class.call(
      journal_entry_id: entry.id, signed_ids: [blob.signed_id]
    )
    expect(result.error?).to be true
    expect(result.content.first[:text]).to include("not writable")
  end
end
