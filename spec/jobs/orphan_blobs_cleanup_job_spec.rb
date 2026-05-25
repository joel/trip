# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrphanBlobsCleanupJob do
  let(:bytes) { Rails.root.join("spec/fixtures/files/test_image.jpg").binread }

  def make_blob(created_at:)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(bytes), filename: "x.jpg", content_type: "image/jpeg"
    ).tap { |b| b.update_columns(created_at: created_at) } # rubocop:disable Rails/SkipsModelValidations
  end

  # The job calls purge_later (background); we just verify which blobs got
  # enqueued, not the actual purge work (covered by Active Storage itself).
  it "enqueues purge for unattached blobs older than the cutoff" do
    old_orphan = make_blob(created_at: 2.hours.ago)

    expect { described_class.new.perform }
      .to have_enqueued_job(ActiveStorage::PurgeJob).with(old_orphan)
  end

  it "does not enqueue purge for recent orphans (in-flight upload window)" do
    make_blob(created_at: 5.minutes.ago)

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end

  it "does not enqueue purge for blobs attached to a record" do
    entry = create(:journal_entry)
    attached = make_blob(created_at: 2.hours.ago)
    entry.images.attach(attached)

    expect { described_class.new.perform }
      .not_to have_enqueued_job(ActiveStorage::PurgeJob).with(attached)
  end
end
