# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::RestoreImage do
  let(:entry) { create(:journal_entry, :with_images) }

  # Remove an image first so there is a real DetachedAttachment + retained blob.
  def remove_one
    blob = entry.images.first.blob
    JournalEntries::RemoveImage.new.call(
      journal_entry: entry, signed_id: blob.signed_id
    )
    DetachedAttachment.last
  end

  it "re-attaches the retained blob to the entry" do
    detached = remove_one
    expect { described_class.new.call(detached_attachment: detached) }
      .to change { entry.reload.images.count }.from(0).to(1)
  end

  it "destroys the DetachedAttachment retention record" do
    detached = remove_one
    expect { described_class.new.call(detached_attachment: detached) }
      .to change(DetachedAttachment, :count).by(-1)
    expect(DetachedAttachment.exists?(detached.id)).to be(false)
  end

  it "emits detached_attachment.restored" do
    detached = remove_one
    allow(Rails.event).to receive(:notify)
    described_class.new.call(detached_attachment: detached)
    expect(Rails.event).to have_received(:notify).with(
      "detached_attachment.restored",
      hash_including(detached_attachment_id: detached.id,
                     journal_entry_id: entry.id, trip_id: entry.trip_id)
    )
  end
end
