# frozen_string_literal: true

class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents, id: :uuid do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.references :user, type: :uuid, null: false,
                          foreign_key: true, index: { unique: true }
      t.timestamps
    end

    add_index :agents, :slug, unique: true
  end
end
