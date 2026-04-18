# frozen_string_literal: true

class AddUniqueIndexOnActiveAccessRequestEmail < ActiveRecord::Migration[8.1]
  def change
    add_index :access_requests, :email,
              unique: true,
              where: "status IN (0, 1)",
              name: "idx_access_requests_active_email_uniqueness"
  end
end
