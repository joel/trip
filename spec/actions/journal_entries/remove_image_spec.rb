# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::RemoveImage do
  let(:entry) { create(:journal_entry, :with_images) }
  let(:blob)  { entry.images.first.blob }
  let(:signed_id) { blob.signed_id }

  it "detaches the image without purging the blob" do
    expect { described_class.new.call(journal_entry: entry, signed_id: signed_id) }
      .to change { entry.reload.images.count }.from(1).to(0)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end

  it "records the removal in a DetachedAttachment" do
    actor = entry.author
    expect { described_class.new.call(journal_entry: entry, signed_id: signed_id, actor: actor) }
      .to change(DetachedAttachment, :count).by(1)
    detached = DetachedAttachment.last
    expect(detached).to have_attributes(
      journal_entry_id: entry.id, blob_id: blob.id, actor_id: actor.id,
      filename: blob.filename.to_s
    )
  end

  it "emits detached_attachment.removed" do
    allow(Rails.event).to receive(:notify)
    described_class.new.call(journal_entry: entry, signed_id: signed_id)
    detached = DetachedAttachment.last
    expect(Rails.event).to have_received(:notify).with(
      "detached_attachment.removed",
      hash_including(detached_attachment_id: detached.id,
                     journal_entry_id: entry.id, trip_id: entry.trip_id,
                     blob_id: blob.id)
    )
  end

  it "fails for a blob not attached to the entry" do
    other = create(:journal_entry, :with_images)
    result = described_class.new.call(
      journal_entry: entry, signed_id: other.images.first.blob.signed_id
    )
    expect(result).to be_failure
  end

  it "fails for an unknown signed_id" do
    result = described_class.new.call(journal_entry: entry, signed_id: "garbage")
    expect(result).to be_failure
  end
end
