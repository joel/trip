# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.references :inviter, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token, null: false
      t.integer :status, null: false, default: 0
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, :email
  end
end
