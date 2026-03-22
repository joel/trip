# frozen_string_literal: true

class CreateTripMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_memberships, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :role, null: false, default: 0
      t.timestamps
    end

    add_index :trip_memberships, %i[trip_id user_id], unique: true
  end
end
