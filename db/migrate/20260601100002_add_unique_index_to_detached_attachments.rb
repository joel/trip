# frozen_string_literal: true

# A blob can be detached from a given journal entry at most once at a time
# (release-scan #2, issue #206). Without this, two concurrent removals of the
# same image could create duplicate DetachedAttachment rows → duplicate feed
# Restore buttons and an odd double-restore. The unique index makes
# JournalEntries::RemoveImage atomic; it rescues RecordNotUnique on the race.
class AddUniqueIndexToDetachedAttachments < ActiveRecord::Migration[8.1]
  def change
    add_index :detached_attachments, %i[journal_entry_id blob_id],
              unique: true,
              name: "idx_detached_attachments_unique_entry_blob"
  end
end
