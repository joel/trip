# frozen_string_literal: true

# Soft-delete for JournalEntryVideo (Phase 26). Mirrors the Phase 25
# discarded_at columns on trips/journal_entries/comments. Discarding the row
# keeps its source/web/poster attachments pointing at it, so the blobs are
# never orphaned and OrphanBlobsCleanupJob leaves them alone.
class AddDiscardedAtToJournalEntryVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_entry_videos, :discarded_at, :datetime
    add_index :journal_entry_videos, :discarded_at
  end
end
