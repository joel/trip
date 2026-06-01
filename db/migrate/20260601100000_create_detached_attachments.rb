# frozen_string_literal: true

# Retention record for a soft-removed image. Active Storage has no native
# soft-delete, so removing one image detaches the ActiveStorage::Attachment
# join row WITHOUT purging the blob and records the detachment here. The row
# exists only while the image is removed (re-attach destroys it) and doubles
# as the Activity-feed auditable identity the Restore button keys on.
# See prompts/Phase 26 Re-attachable Media.md §5.2.
class CreateDetachedAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :detached_attachments, id: :uuid do |t|
      t.references :journal_entry, type: :uuid, null: false,
                                   foreign_key: true
      t.uuid :blob_id, null: false      # the retained ActiveStorage::Blob
      t.uuid :actor_id                  # who removed it (denormalised, nullable)
      t.string :filename                # denormalised for feed render
      t.string :content_type
      t.bigint :byte_size
      t.timestamps
    end

    add_index :detached_attachments, :blob_id
  end
end
