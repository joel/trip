# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Bootstrap superadmin (bypasses Rodauth invitation gate)
admin = User.find_or_create_by!(email: "admin@tripjournal.app") do |u|
  u.name = "Admin"
  u.status = 2 # verified
end
admin.update!(roles: [:superadmin]) unless admin.role?(:superadmin)
