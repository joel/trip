# frozen_string_literal: true

# Periodically purge ActiveStorage::Blob rows that were created via
# `create_before_direct_upload!` (or the project's
# ActiveStorageBlobBuilder.prepare_for_direct_upload, called by the
# MCP prepare_journal_*_upload tools and the web-form Direct Upload
# path) but never attached to a record. Without this, abandoned
# prepares — agent gets a signed_id, never PUTs; or PUTs but never
# calls add_journal_* with the signed_id; or a user picks a file and
# walks away mid-form — leak storage in SeaweedFS and rows in the DB.
#
# Scheduled hourly via config/recurring.yml.
#
# Window: 24 hours. The web form direct-uploads a blob the moment
# the user picks a file, and that blob is only attached on submit —
# the gap can be a long edit session. 24h is comfortably longer
# than any reasonable in-flight upload + composition window while
# still catching genuine leaks the same day (raised from 1h after
# Codex flagged the risk to in-progress form sessions).
class OrphanBlobsCleanupJob < ApplicationJob
  queue_as :background

  CUTOFF = 24.hours

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
