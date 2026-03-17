class AddRolesMaskToUsers < ActiveRecord::Migration[8.1]
  def change
    roles = %i[superadmin admin member contributor guest]
    default_mask = 1 << roles.index(:guest)

    add_column :users, :roles_mask, :integer, null: false, default: default_mask
  end
end
