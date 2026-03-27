# frozen_string_literal: true

class CreateJournalEntrySubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entry_subscriptions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false,
                          foreign_key: true
      t.references :journal_entry, type: :uuid, null: false,
                                   foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :journal_entry_subscriptions,
              %i[user_id journal_entry_id],
              unique: true,
              name: "idx_entry_subscriptions_uniqueness"
  end
end
