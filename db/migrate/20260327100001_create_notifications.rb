# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.string :notifiable_type, null: false
      t.uuid :notifiable_id, null: false
      t.references :recipient, type: :uuid, null: false,
                               foreign_key: { to_table: :users }
      t.references :actor, type: :uuid, null: false,
                           foreign_key: { to_table: :users }
      t.integer :event_type, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, %i[notifiable_type notifiable_id]
    add_index :notifications, %i[recipient_id read_at]
    add_index :notifications, %i[recipient_id created_at]
    add_index :notifications,
              %i[notifiable_type notifiable_id recipient_id event_type],
              unique: true, name: "idx_notifications_uniqueness"
  end
end
