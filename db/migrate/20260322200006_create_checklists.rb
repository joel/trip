# frozen_string_literal: true

class CreateChecklists < ActiveRecord::Migration[8.0]
  def change
    create_table :checklists, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
