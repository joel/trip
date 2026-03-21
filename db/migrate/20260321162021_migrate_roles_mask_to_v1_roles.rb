# frozen_string_literal: true

class MigrateRolesMaskToV1Roles < ActiveRecord::Migration[8.1]
  # Old roles: [:superadmin(0), :admin(1), :member(2), :contributor(3), :guest(4)]
  # New roles: [:superadmin(0), :contributor(1), :viewer(2), :guest(3)]
  #
  # Bit mapping:
  #   old superadmin (1)  -> new superadmin (1)
  #   old admin      (2)  -> new superadmin (1)
  #   old member     (4)  -> new viewer     (4)
  #   old contributor (8) -> new contributor (2)
  #   old guest      (16) -> new guest      (8)

  def up
    execute <<~SQL
      UPDATE users SET roles_mask = (
        CASE
          WHEN roles_mask & 1 != 0 THEN 1 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 2 != 0 THEN 1 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 4 != 0 THEN 4 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 8 != 0 THEN 2 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 16 != 0 THEN 8 ELSE 0
        END
      )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users SET roles_mask = (
        CASE
          WHEN roles_mask & 1 != 0 THEN 1 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 2 != 0 THEN 8 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 4 != 0 THEN 4 ELSE 0
        END
        |
        CASE
          WHEN roles_mask & 8 != 0 THEN 16 ELSE 0
        END
      )
    SQL
  end
end
