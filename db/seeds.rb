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

# Seed sample trip
trip = Trip.find_or_create_by!(name: "Sample Trip") do |t|
  t.created_by = admin
  t.description = "A sample trip to demonstrate the journal."
  t.state = :planning
end

TripMembership.find_or_create_by!(trip: trip, user: admin) do |tm|
  tm.role = :contributor
end

JournalEntry.find_or_create_by!(trip: trip, name: "Arrival Day") do |je|
  je.author = admin
  je.entry_date = Date.current
  je.location_name = "Sample Location"
  je.description = "First day of our sample trip."
end

puts "Seeded sample trip: #{trip.name} (id: #{trip.id})"
