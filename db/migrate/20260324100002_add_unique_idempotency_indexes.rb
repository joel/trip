# frozen_string_literal: true

class AddUniqueIdempotencyIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :journal_entries, %i[trip_id telegram_message_id],
              unique: true,
              where: "telegram_message_id IS NOT NULL",
              name: "idx_journal_entries_telegram_idempotency"

    add_index :comments, %i[journal_entry_id telegram_message_id],
              unique: true,
              where: "telegram_message_id IS NOT NULL",
              name: "idx_comments_telegram_idempotency"
  end
end
