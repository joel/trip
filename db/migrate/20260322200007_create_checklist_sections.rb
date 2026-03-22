# frozen_string_literal: true

class CreateChecklistSections < ActiveRecord::Migration[8.0]
  def change
    create_table :checklist_sections, id: :uuid do |t|
      t.references :checklist, type: :uuid, null: false,
                                foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
