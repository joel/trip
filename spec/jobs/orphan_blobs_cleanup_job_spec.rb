# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrphanBlobsCleanupJob do
  let(:bytes) { Rails.root.join("spec/fixtures/files/test_image.jpg").binread }

  def make_blob(created_at:)
    ActiveStorageBlobBuilder.upload(
      io: StringIO.new(bytes), filename: "x.jpg", content_type: "image/jpeg"
    ).tap { |b| b.update_columns(created_at: created_at) } # rubocop:disable Rails/SkipsModelValidations
  end

  # The job calls purge_later (background); we just verify which blobs got
  # enqueued, not the actual purge work (covered by Active Storage itself).
  it "enqueues purge for unattached blobs older than the 24h cutoff" do
    old_orphan = make_blob(created_at: 25.hours.ago)

    expect { described_class.new.perform }
      .to have_enqueued_job(ActiveStorage::PurgeJob).with(old_orphan)
  end

  it "keeps web-form direct-upload blobs sitting in a long edit session (< 24h)" do
    # The web form direct-uploads on file-select, attaches on submit;
    # a 90-minute edit session must NOT lose its uploads.
    make_blob(created_at: 90.minutes.ago)

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end

  it "does not enqueue purge for recent orphans" do
    make_blob(created_at: 5.minutes.ago)

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end

  it "does not enqueue purge for blobs attached to a record" do
    entry = create(:journal_entry)
    attached = make_blob(created_at: 25.hours.ago)
    entry.images.attach(attached)

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob).with(attached)
  end

  # Phase 26 (load-bearing): a soft-removed image is detached (no attachment
  # row) but its blob is retained for restore via a DetachedAttachment. The
  # sweep must never purge it, even old + unattached — otherwise removed
  # photos vanish 24h later.
  it "does not enqueue purge for a blob retained by a DetachedAttachment" do
    entry = create(:journal_entry)
    retained = make_blob(created_at: 25.hours.ago)
    DetachedAttachment.create!(
      journal_entry: entry, blob_id: retained.id,
      filename: "x.jpg", content_type: "image/jpeg", byte_size: retained.byte_size
    )

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob).with(retained)
  end

  it "still purges a genuine orphan while a retained blob coexists" do
    entry = create(:journal_entry)
    retained = make_blob(created_at: 25.hours.ago)
    DetachedAttachment.create!(
      journal_entry: entry, blob_id: retained.id,
      filename: "x.jpg", content_type: "image/jpeg", byte_size: retained.byte_size
    )
    orphan = make_blob(created_at: 25.hours.ago)

    expect { described_class.new.perform }
      .to have_enqueued_job(ActiveStorage::PurgeJob).with(orphan)
  end
end
