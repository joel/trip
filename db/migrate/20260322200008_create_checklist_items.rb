# frozen_string_literal: true

class CreateChecklistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :checklist_items, id: :uuid do |t|
      t.references :checklist_section, type: :uuid, null: false,
                                        foreign_key: true
      t.string :content, null: false
      t.boolean :completed, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
