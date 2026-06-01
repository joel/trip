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

  # release-scan #2: the unique index makes a concurrent double-removal safe.
  it "does not create a duplicate retention row when one already exists" do
    # A retention row already present for this blob (a concurrent removal that
    # committed first) while the attachment is still attached.
    DetachedAttachment.create!(
      journal_entry: entry, blob_id: blob.id,
      filename: "x.jpg", content_type: "image/jpeg", byte_size: blob.byte_size
    )

    result = nil
    expect { result = described_class.new.call(journal_entry: entry, signed_id: signed_id) }
      .not_to change(DetachedAttachment, :count)
    expect(result).to be_failure
    # Our transaction rolled back: the attachment is untouched.
    expect(entry.reload.images.count).to eq(1)
  end

  # Regression: has_many_attached defaults to dependent: :purge_later, so a plain
  # attachment.destroy would purge the blob once the job runs. Prove the blob
  # survives even when jobs run inline (i.e. production).
  it "retains the blob even when purge jobs run inline" do
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    described_class.new.call(journal_entry: entry, signed_id: signed_id)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    expect(ActiveStorage::Attachment.exists?(blob_id: blob.id)).to be(false)
  ensure
    ActiveJob::Base.queue_adapter = adapter
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
