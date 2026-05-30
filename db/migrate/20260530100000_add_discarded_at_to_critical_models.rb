# frozen_string_literal: true

class AddDiscardedAtToCriticalModels < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :discarded_at, :datetime
    add_column :journal_entries, :discarded_at, :datetime
    add_column :comments, :discarded_at, :datetime

    add_index :trips, :discarded_at
    add_index :journal_entries, :discarded_at
    add_index :comments, :discarded_at
  end
end
