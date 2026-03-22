# frozen_string_literal: true

class CreateJournalEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_entries, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.references :author, type: :uuid, null: false,
                            foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.date :entry_date, null: false
      t.string :location_name
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :actor_type
      t.string :actor_id
      t.string :telegram_message_id
      t.string :telegram_chat_id
      t.timestamps
    end

    add_index :journal_entries,
              %i[trip_id entry_date created_at id],
              name: "idx_journal_entries_chronological"
    add_index :journal_entries, :telegram_message_id
  end
end
