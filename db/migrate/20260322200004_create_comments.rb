# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :journal_entry, type: :uuid, null: false,
                                    foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    add_index :comments, %i[journal_entry_id created_at]
  end
end
