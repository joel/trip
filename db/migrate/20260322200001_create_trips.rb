# frozen_string_literal: true

class CreateTrips < ActiveRecord::Migration[8.0]
  def change
    create_table :trips, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.integer :state, null: false, default: 0
      t.json :metadata, null: false, default: {}
      t.date :start_date
      t.date :end_date
      t.references :created_by, type: :uuid, null: false,
                                foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
