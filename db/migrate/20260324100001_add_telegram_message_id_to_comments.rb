# frozen_string_literal: true

class AddTelegramMessageIdToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :telegram_message_id, :string
    add_index :comments, :telegram_message_id
  end
end
