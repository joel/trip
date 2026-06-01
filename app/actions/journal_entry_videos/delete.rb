# frozen_string_literal: true

module JournalEntryVideos
  # Soft-removes one video from a journal entry: discards the JournalEntryVideo
  # row (its source/web/poster attachments stay, so the blobs are never
  # orphaned) and emits "journal_entry_video.removed". Restore is parent-only
  # (Phase 26 §5.1). Resolve trip_id from the entry up front so the event
  # payload carries it even though the row is now discarded.
  class Delete < BaseAction
    def call(video:)
      video_id = video.id
      entry = JournalEntry.with_discarded.find(video.journal_entry_id)
      yield discard(video)
      yield emit_event(video_id, entry)
      Success(video)
    end

    private

    def discard(video)
      video.discard!
      Success()
    end

    def emit_event(video_id, entry)
      Rails.event.notify(
        "journal_entry_video.removed",
        journal_entry_video_id: video_id,
        journal_entry_id: entry.id,
        trip_id: entry.trip_id
      )
      Success()
    end
  end
end
