# frozen_string_literal: true

class CreateJournalEntryVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entry_videos, id: :uuid do |t|
      t.references :journal_entry, type: :uuid, null: false,
                                   foreign_key: true
      t.integer :status, null: false, default: 0
      t.float :duration
      t.integer :width
      t.integer :height
      t.integer :position, null: false, default: 0
      t.text :error_message
      t.timestamps
    end

    add_index :journal_entry_videos, %i[journal_entry_id position],
              name: "idx_journal_entry_videos_ordering"
  end
end
