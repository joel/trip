# frozen_string_literal: true

class ChangeDefaultRolesMaskForUsers < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :roles_mask, 8
  end

  def down
    change_column_default :users, :roles_mask, 16
  end
end
