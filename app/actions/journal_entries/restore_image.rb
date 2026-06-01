# frozen_string_literal: true

module JournalEntries
  # Restores a soft-removed image: re-attaches the retained blob to the journal
  # entry and destroys the DetachedAttachment retention record (its existence
  # was the "removed" state). Emits "detached_attachment.restored". Counterpart
  # to JournalEntries::RemoveImage. See prompts/Phase 26 §5.2.
  class RestoreImage < BaseAction
    def call(detached_attachment:)
      entry = JournalEntry.with_discarded.find(detached_attachment.journal_entry_id)
      yield reattach(entry, detached_attachment)
      yield emit_event(entry, detached_attachment)
      Success(detached_attachment)
    end

    private

    # Re-create the attachment from the retained blob, then drop the retention
    # record. One transaction so we never end up re-attached-but-still-recorded
    # (which would offer a phantom Restore) or recorded-but-not-attached.
    def reattach(entry, detached)
      ActiveRecord::Base.transaction do
        entry.images.attach(detached.blob)
        detached.destroy!
      end
      Success()
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      Failure(e.message)
    end

    def emit_event(entry, detached)
      Rails.event.notify(
        "detached_attachment.restored",
        detached_attachment_id: detached.id,
        journal_entry_id: entry.id,
        trip_id: entry.trip_id,
        filename: detached.filename
      )
      Success()
    end
  end
end
