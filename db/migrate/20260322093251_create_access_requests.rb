# frozen_string_literal: true

class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests, id: :uuid do |t|
      t.string :email, null: false
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }, null: true
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :access_requests, :email
  end
end
