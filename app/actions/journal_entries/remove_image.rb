# frozen_string_literal: true

module JournalEntries
  # Soft-removes one image from a journal entry. Active Storage has no native
  # soft-delete, so we detach the ActiveStorage::Attachment join row WITHOUT
  # purging — the blob + stored file survive — and record the removal in a
  # DetachedAttachment (which is also the Activity-feed auditable). Restore via
  # JournalEntries::RestoreImage. See prompts/Phase 26 Re-attachable Media.md
  # §5.2.
  #
  # The retained blob is protected from OrphanBlobsCleanupJob by the
  # DetachedAttachment reference (§5.3).
  class RemoveImage < BaseAction
    def call(journal_entry:, signed_id:, actor: nil)
      blob = yield find_blob(signed_id)
      attachment = yield find_attachment(journal_entry, blob)
      detached = yield detach(journal_entry, blob, attachment, actor)
      yield emit_event(journal_entry, detached, blob)
      Success(detached)
    end

    private

    def find_blob(signed_id)
      blob = ActiveStorage::Blob.find_signed(signed_id)
      blob ? Success(blob) : Failure("Image not found")
    end

    def find_attachment(journal_entry, blob)
      attachment = ActiveStorage::Attachment.find_by(
        record: journal_entry, name: "images", blob_id: blob.id
      )
      return Success(attachment) if attachment

      Failure("Image is not attached to this entry")
    end

    # Create the retention record, then remove the join row WITHOUT purge so
    # the blob + file are retained for restore. One transaction so a failure
    # leaves neither a dangling record nor a detached-but-unrecorded blob.
    #
    # `attachment.delete` (not `destroy`) is deliberate: `has_many_attached`
    # defaults to dependent: :purge_later, so `attachment.destroy` fires an
    # after_destroy_commit that purges the blob (deleting the file) the moment
    # the job runs — exactly what Phase 26 must avoid. `delete` skips callbacks,
    # leaving the blob intact. (The :test queue adapter hid this; an inline
    # adapter — i.e. production — would lose the file.)
    def detach(journal_entry, blob, attachment, actor)
      detached = nil
      ActiveRecord::Base.transaction do
        detached = DetachedAttachment.create!(
          journal_entry: journal_entry,
          blob_id: blob.id,
          actor_id: actor&.id,
          filename: blob.filename.to_s,
          content_type: blob.content_type,
          byte_size: blob.byte_size
        )
        attachment.delete
      end
      Success(detached)
    end

    def emit_event(journal_entry, detached, blob)
      Rails.event.notify(
        "detached_attachment.removed",
        detached_attachment_id: detached.id,
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        blob_id: blob.id,
        filename: detached.filename
      )
      Success()
    end
  end
end
