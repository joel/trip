# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

admin_email = ENV.fetch("ADMIN_EMAIL", "joel@acme.org")

# Bootstrap superadmin (bypasses Rodauth invitation gate).
# Status 2 = verified in Rodauth, so the admin can log in immediately via email auth.
admin = User.find_or_initialize_by(email: admin_email)
admin.name ||= "Admin"
admin.status = 2
admin.roles = [:superadmin]
admin.save!

puts "Seeded superadmin: #{admin.email} (id: #{admin.id})"
