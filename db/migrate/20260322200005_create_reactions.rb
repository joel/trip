# frozen_string_literal: true

class CreateReactions < ActiveRecord::Migration[8.0]
  def change
    create_table :reactions, id: :uuid do |t|
      t.string :reactable_type, null: false
      t.uuid :reactable_id, null: false
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :emoji, null: false
      t.datetime :created_at, null: false
    end

    add_index :reactions, %i[reactable_type reactable_id]
    add_index :reactions,
              %i[reactable_type reactable_id user_id emoji],
              unique: true, name: "idx_reactions_uniqueness"
  end
end
