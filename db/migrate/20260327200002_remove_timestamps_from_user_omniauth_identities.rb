# frozen_string_literal: true

class RemoveTimestampsFromUserOmniauthIdentities < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_omniauth_identities, :created_at, :datetime
    remove_column :user_omniauth_identities, :updated_at, :datetime
  end
end
