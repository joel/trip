# frozen_string_literal: true

# Retention record for a soft-removed image (Phase 26). When a user removes one
# image from a journal entry, JournalEntries::RemoveImage detaches the
# ActiveStorage::Attachment WITHOUT purging the blob and creates this row. Its
# existence IS the "removed" state — JournalEntries::RestoreImage re-attaches
# the blob and destroys the row. It also serves as the Activity-feed auditable
# so the Restore button can key on it. See prompts/Phase 26 Re-attachable
# Media.md §5.2.
#
# OrphanBlobsCleanupJob excludes blobs referenced here so a retained image is
# never swept (§5.3) — the single load-bearing data-safety guarantee.
class DetachedAttachment < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :blob, class_name: "ActiveStorage::Blob"
  belongs_to :actor, class_name: "User", optional: true
end
