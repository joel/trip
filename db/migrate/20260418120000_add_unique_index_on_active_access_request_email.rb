# frozen_string_literal: true

class AddUniqueIndexOnActiveAccessRequestEmail < ActiveRecord::Migration[8.1]
  INDEX_NAME = "idx_access_requests_active_email_uniqueness"

  def up
    reconcile_duplicate_active_requests
    add_index :access_requests, :email,
              unique: true,
              where: "status IN (0, 1)",
              name: INDEX_NAME
  end

  def down
    remove_index :access_requests, name: INDEX_NAME
  end

  private

  # Mark older pending/approved rows that share an email with a newer
  # pending/approved row as rejected, so the partial unique index on
  # (email) WHERE status IN (0, 1) can be created without conflict.
  # Deletions are avoided so the original submission history is
  # preserved in the audit trail.
  def reconcile_duplicate_active_requests
    execute <<~SQL.squish
      UPDATE access_requests
      SET status = 2,
          reviewed_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE status IN (0, 1)
        AND EXISTS (
          SELECT 1 FROM access_requests newer
          WHERE newer.email = access_requests.email
            AND newer.status IN (0, 1)
            AND (newer.created_at > access_requests.created_at
                 OR (newer.created_at = access_requests.created_at
                     AND newer.id > access_requests.id))
        )
    SQL
  end
end
