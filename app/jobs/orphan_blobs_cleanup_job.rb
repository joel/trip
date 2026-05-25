# frozen_string_literal: true

# Periodically purge ActiveStorage::Blob rows that were created via
# `create_before_direct_upload!` (by the MCP prepare_journal_*_upload
# tools or the web-form Direct Upload path) but never attached to a
# record. Without this, abandoned prepares — agent gets a signed_id,
# never PUTs; or PUTs but never calls add_journal_*_upload with the
# signed_id — leak storage in SeaweedFS and rows in the DB.
#
# Scheduled hourly via config/recurring.yml.
#
# Window: `created_at < 1.hour.ago`. The 10-minute presign expiry on
# the prepare tools means an in-flight upload finishes well within
# the cutoff; we keep a comfortable margin so a slow agent has time
# to finish the PUT + the add_journal_* call.
class OrphanBlobsCleanupJob < ApplicationJob
  queue_as :background

  CUTOFF = 1.hour

  def perform
    cutoff_time = CUTOFF.ago
    scope = ActiveStorage::Blob
            .left_joins(:attachments)
            .where(active_storage_attachments: { id: nil })
            .where(active_storage_blobs: { created_at: ...cutoff_time })

    purged = 0
    scope.find_each do |blob|
      blob.purge_later
      purged += 1
    end
    Rails.logger.info(
      "[OrphanBlobsCleanupJob] enqueued #{purged} purge jobs " \
      "(cutoff: #{cutoff_time.iso8601})"
    )
  end
end
