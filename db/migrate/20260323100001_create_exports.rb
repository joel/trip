# frozen_string_literal: true

class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :format, null: false
      t.integer :status, default: 0, null: false
      t.timestamps
    end

    add_index :exports, %i[trip_id user_id created_at]
  end
end
