# frozen_string_literal: true

# Creates the paper_trail `versions` table. UUID-corrected for this app:
# the table itself uses a UUID PK and `item_id` is a UUID (all app PKs are
# UUID, stored via the sqlite_crypto fork — mirrors db/audit_logs).
# `object` / `object_changes` keep paper_trail's default text + YAML serializer
# (most battle-tested for `reify`); SQLite ignores the byte limit.
class CreateVersions < ActiveRecord::Migration[8.1]
  TEXT_BYTES = 1_073_741_823

  def change
    create_table :versions, id: :uuid do |t|
      t.string   :whodunnit
      t.datetime :created_at
      t.uuid     :item_id,   null: false
      t.string   :item_type, null: false
      t.string   :event,     null: false
      t.text     :object, limit: TEXT_BYTES
    end
    add_index :versions, %i[item_type item_id]
  end
end
