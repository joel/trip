# frozen_string_literal: true

# Adds the optional `object_changes` column where paper_trail stores the
# per-update diff (`--with-changes`). Text column holding JSON, matching
# `object` (the JSON serializer is set in config/initializers/paper_trail.rb).
class AddObjectChangesToVersions < ActiveRecord::Migration[8.1]
  TEXT_BYTES = 1_073_741_823

  def change
    add_column :versions, :object_changes, :text, limit: TEXT_BYTES
  end
end
