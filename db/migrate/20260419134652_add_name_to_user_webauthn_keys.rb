# frozen_string_literal: true

class AddNameToUserWebauthnKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :user_webauthn_keys, :name, :string, limit: 80
  end
end
