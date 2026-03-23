# frozen_string_literal: true

# Comprehensive seed data covering all model states.
# Idempotent — safe to run multiple times via `bin/rails db:seed`.

require "open-uri"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def log(msg)
  puts "  #{msg}"
end

def create_user(email:, name:, roles:)
  user = User.find_or_initialize_by(email: email)
  user.name = name
  user.status = 2 # Rodauth verified
  user.roles = roles
  user.save!
  user
end

def attach_seed_images(record, seed_names)
  return if record.images.attached? && record.images.count >= seed_names.size

  seed_names.each do |seed_name|
    io = URI.open(
      "https://picsum.photos/seed/#{seed_name}/800/600",
      open_timeout: 5, read_timeout: 10
    )
    record.images.attach(
      io: io, filename: "#{seed_name}.jpg",
      content_type: "image/jpeg"
    )
  rescue OpenURI::HTTPError, SocketError,
         Errno::ECONNREFUSED, Timeout::Error => e
    log "[SKIP] Image #{seed_name}: #{e.message}"
  end
end

def transition_trip!(trip, *states)
  states.each do |state|
    trip.transition_to!(state) if trip.can_transition_to?(state)
  end
end

def seed_entry(trip:, author:, name:, date:, location:,
               lat:, lng:, body_html:, image_seeds: [])
  entry = JournalEntry.find_or_create_by!(trip: trip, name: name) do |je|
    je.author = author
    je.entry_date = date
    je.location_name = location
    je.latitude = lat
    je.longitude = lng
    je.description = body_html.gsub(/<[^>]+>/, "").truncate(200)
  end
  entry.update!(body: body_html) if entry.body.blank?
  attach_seed_images(entry, image_seeds) if image_seeds.any?
  entry
end

# ---------------------------------------------------------------------------
# 1. Users
# ---------------------------------------------------------------------------

puts "\n--- Users ---"

admin = create_user(
  email: ENV.fetch("ADMIN_EMAIL", "joel@acme.org"),
  name: "Joel Azemar", roles: [:superadmin]
)
log "Superadmin: #{admin.email}"

alice = create_user(
  email: "alice@acme.org",
  name: "Alice Martin", roles: [:contributor]
)
bob = create_user(
  email: "bob@acme.org",
  name: "Bob Chen", roles: [:contributor]
)
carol = create_user(
  email: "carol@acme.org",
  name: "Carol Nguyen", roles: [:contributor]
)
dave = create_user(
  email: "dave@acme.org",
  name: "Dave Wilson", roles: [:viewer]
)
eve = create_user(
  email: "eve@acme.org",
  name: "Eve Santos", roles: [:viewer]
)
log "Created #{User.count} users"

# ---------------------------------------------------------------------------
# 2. Trips (one per state)
# ---------------------------------------------------------------------------

puts "\n--- Trips ---"

japan = Trip.find_or_create_by!(name: "Japan Spring Tour") do |t|
  t.created_by = admin
  t.description = "Two weeks exploring cherry blossoms, temples, and street food across Japan."
  t.start_date = 30.days.ago.to_date
  t.end_date = 16.days.ago.to_date
end
transition_trip!(japan, :started, :finished)
log "#{japan.name} [#{japan.state}]"

iceland = Trip.find_or_create_by!(name: "Iceland Road Trip") do |t|
  t.created_by = alice
  t.description = "Ring road adventure through volcanoes, glaciers, and hot springs."
  t.start_date = 7.days.ago.to_date
end
transition_trip!(iceland, :started)
log "#{iceland.name} [#{iceland.state}]"

barcelona = Trip.find_or_create_by!(name: "Weekend in Barcelona") do |t|
  t.created_by = bob
  t.description = "Quick getaway to explore Gaudi, tapas, and the beach."
  t.start_date = 14.days.from_now.to_date
  t.end_date = 16.days.from_now.to_date
end
log "#{barcelona.name} [#{barcelona.state}]"

norway = Trip.find_or_create_by!(name: "Norway Fjords") do |t|
  t.created_by = admin
  t.description = "Scenic fjord cruise that was unfortunately called off."
end
transition_trip!(norway, :cancelled)
log "#{norway.name} [#{norway.state}]"

patagonia = Trip.find_or_create_by!(name: "Patagonia Trek") do |t|
  t.created_by = carol
  t.description = "Epic hiking through glaciers and mountains at the end of the world."
  t.start_date = 90.days.ago.to_date
  t.end_date = 75.days.ago.to_date
end
transition_trip!(patagonia, :started, :finished, :archived)
log "#{patagonia.name} [#{patagonia.state}]"

# ---------------------------------------------------------------------------
# 3. Trip Memberships
# ---------------------------------------------------------------------------

puts "\n--- Memberships ---"

memberships = {
  japan => { admin => :contributor, alice => :contributor,
             bob => :contributor, dave => :viewer, eve => :viewer },
  iceland => { alice => :contributor, bob => :contributor,
               carol => :contributor, dave => :viewer },
  barcelona => { bob => :contributor, alice => :contributor,
                 eve => :viewer },
  norway => { admin => :contributor, carol => :contributor },
  patagonia => { carol => :contributor, alice => :contributor,
                 bob => :viewer }
}

memberships.each do |trip, members|
  members.each do |user, role|
    TripMembership.find_or_create_by!(trip: trip, user: user) do |tm|
      tm.role = role
    end
  end
end
log "Created #{TripMembership.count} memberships"

# ---------------------------------------------------------------------------
# 4. Journal Entries (with rich text + images)
# ---------------------------------------------------------------------------

puts "\n--- Journal Entries ---"

# -- Japan Spring Tour --
jp1 = seed_entry(
  trip: japan, author: admin, name: "Arrival in Tokyo",
  date: 30.days.ago.to_date,
  location: "Tokyo, Japan", lat: 35.6762, lng: 139.6503,
  body_html: <<~HTML,
    <p>Touched down at Narita after a long flight. The energy of Tokyo hit us
    immediately — neon signs, the hum of trains, and the smell of ramen from
    every corner.</p>
    <p>Checked into our hotel in <strong>Shinjuku</strong> and took an evening
    walk through <em>Kabukicho</em>. The cherry blossoms are just starting to
    bloom along the Kanda River.</p>
  HTML
  image_seeds: %w[japan-tokyo-1 japan-tokyo-2]
)

jp2 = seed_entry(
  trip: japan, author: alice, name: "Shibuya and Harajuku",
  date: 28.days.ago.to_date,
  location: "Shibuya, Tokyo", lat: 35.6595, lng: 139.7005,
  body_html: <<~HTML,
    <p>Started the day at the famous <strong>Shibuya Crossing</strong> — it
    really is as wild as the videos make it look. We crossed it three times
    just for fun.</p>
    <p>Harajuku's Takeshita Street was a sensory overload of color, crepes,
    and fashion. Found an incredible vintage kimono shop tucked in a side
    alley.</p>
  HTML
  image_seeds: %w[japan-shibuya-1 japan-harajuku-1]
)

jp3 = seed_entry(
  trip: japan, author: bob, name: "Day Trip to Kamakura",
  date: 25.days.ago.to_date,
  location: "Kamakura, Japan", lat: 35.3192, lng: 139.5467,
  body_html: <<~HTML,
    <p>Took the train south to Kamakura to see the <strong>Great Buddha</strong>.
    The bronze statue is even more impressive in person — 13 meters of serene
    contemplation.</p>
    <p>Walked the bamboo groves at Hokoku-ji temple and had matcha in their
    garden. A perfect escape from the city buzz.</p>
  HTML
  image_seeds: %w[japan-kamakura-1]
)

jp4 = seed_entry(
  trip: japan, author: admin, name: "Kyoto Temples",
  date: 22.days.ago.to_date,
  location: "Kyoto, Japan", lat: 35.0116, lng: 135.7681,
  body_html: <<~HTML,
    <p>Kyoto is everything I imagined and more. We started early at
    <strong>Fushimi Inari</strong> — thousands of vermillion torii gates
    winding up the mountainside.</p>
    <p>Afternoon at <em>Kinkaku-ji</em> (Golden Pavilion) with its mirror
    reflection in the pond. Finished the day with a kaiseki dinner in
    Gion.</p>
  HTML
  image_seeds: %w[japan-kyoto-1 japan-kyoto-2]
)

jp5 = seed_entry(
  trip: japan, author: alice, name: "Last Day in Osaka",
  date: 17.days.ago.to_date,
  location: "Osaka, Japan", lat: 34.6937, lng: 135.5023,
  body_html: <<~HTML,
    <p>Osaka is the food capital. <strong>Dotonbori</strong> at night is pure
    magic — giant moving signs, the smell of takoyaki, and locals shouting
    welcomes from every stall.</p>
    <p>Had the best okonomiyaki of my life at a tiny spot under the train
    tracks. Already planning the next trip back.</p>
  HTML
  image_seeds: %w[japan-osaka-1]
)

# -- Iceland Road Trip --
ic1 = seed_entry(
  trip: iceland, author: alice, name: "Landing in Reykjavik",
  date: 7.days.ago.to_date,
  location: "Reykjavik, Iceland", lat: 64.1466, lng: -21.9426,
  body_html: <<~HTML,
    <p>The descent into Keflavik was otherworldly — black lava fields
    stretching to the horizon under a steel-grey sky. Picked up our 4x4
    and drove through lunar landscapes to <strong>Reykjavik</strong>.</p>
    <p>Explored the colorful downtown, visited <em>Hallgrimskirkja</em>,
    and warmed up in a local hot pot. The wind here is relentless.</p>
  HTML
  image_seeds: %w[iceland-reykjavik-1 iceland-reykjavik-2]
)

ic2 = seed_entry(
  trip: iceland, author: bob, name: "Golden Circle Drive",
  date: 5.days.ago.to_date,
  location: "Thingvellir, Iceland", lat: 64.2559, lng: -21.1290,
  body_html: <<~HTML,
    <p>Drove the Golden Circle today. <strong>Thingvellir</strong> is where
    the North American and Eurasian tectonic plates pull apart — you can
    literally walk between continents.</p>
    <p>Gullfoss waterfall was thundering with snowmelt. Geysir erupted every
    few minutes, shooting steam 20 meters into the air. Nature at its most
    raw and powerful.</p>
  HTML
  image_seeds: %w[iceland-thingvellir-1 iceland-golden-1]
)

ic3 = seed_entry(
  trip: iceland, author: carol, name: "Glacier Lagoon",
  date: 3.days.ago.to_date,
  location: "Jokulsarlon, Iceland", lat: 64.0784, lng: -16.2306,
  body_html: <<~HTML,
    <p>Drove six hours east to <strong>Jokulsarlon glacier lagoon</strong>.
    Icebergs the size of houses floating past in silence. Some are crystal
    blue, others streaked with volcanic ash.</p>
    <p>Walked to nearby Diamond Beach where ice chunks wash up on black
    sand. It looks like scattered jewels. Absolutely surreal.</p>
  HTML
  image_seeds: %w[iceland-glacier-1]
)

# -- Patagonia Trek --
pt1 = seed_entry(
  trip: patagonia, author: carol, name: "Arriving in El Calafate",
  date: 90.days.ago.to_date,
  location: "El Calafate, Argentina", lat: -50.3382, lng: -72.2647,
  body_html: <<~HTML,
    <p>Made it to the gateway to Patagonian glaciers. El Calafate is a small
    town hugging Lago Argentino, with the Andes rising sharply behind it.</p>
    <p>Stocked up on supplies and booked our glacier excursion. The wind down
    here is fierce — locals joke it never stops.</p>
  HTML
  image_seeds: %w[patagonia-calafate-1]
)

pt2 = seed_entry(
  trip: patagonia, author: alice, name: "Perito Moreno Glacier",
  date: 88.days.ago.to_date,
  location: "Perito Moreno, Argentina", lat: -50.4967, lng: -73.1377,
  body_html: <<~HTML,
    <p>Standing in front of <strong>Perito Moreno</strong> is humbling. The
    glacier is 5 km wide and 60 meters tall. Every few minutes a chunk of ice
    the size of a building calves off with a crack like thunder.</p>
    <p>Did the mini-trekking on the glacier itself — crampons on, walking
    across blue ice crevasses. One of the most memorable experiences of my
    life.</p>
  HTML
  image_seeds: %w[patagonia-moreno-1 patagonia-moreno-2]
)

pt3 = seed_entry(
  trip: patagonia, author: carol, name: "Torres del Paine",
  date: 82.days.ago.to_date,
  location: "Torres del Paine, Chile", lat: -50.9423, lng: -73.4068,
  body_html: <<~HTML,
    <p>Crossed into Chile for <strong>Torres del Paine</strong> national park.
    The three granite towers piercing the sky are iconic for a reason — they
    look painted against the Patagonian sky.</p>
    <p>Hiked to the base of the towers. The last stretch is a brutal scramble
    over boulders, but the turquoise glacial lake at the top makes every step
    worth it.</p>
  HTML
  image_seeds: %w[patagonia-torres-1 patagonia-torres-2]
)

log "Created #{JournalEntry.count} journal entries"

# ---------------------------------------------------------------------------
# 5. Comments
# ---------------------------------------------------------------------------

puts "\n--- Comments ---"

comments_data = [
  [jp1, alice, "Welcome to Japan! The cherry blossoms sound magical."],
  [jp1, dave, "Shinjuku at night is incredible. Great photos!"],
  [jp4, bob, "Fushimi Inari is on my bucket list. How early did you start?"],
  [jp4, eve, "The Golden Pavilion reflection shot is stunning."],
  [jp5, carol, "Dotonbori is heaven for foodies. Try the kushikatsu!"],
  [ic1, admin, "Stay warm out there! Reykjavik in spring is still chilly."],
  [ic1, carol, "The colorful houses are so charming."],
  [ic2, bob, "Walking between tectonic plates is surreal."],
  [ic2, dave, "How was the weather? Looks windy from the photos."],
  [pt2, alice, "Glaciers are awe-inspiring. The blue ice is unreal."],
  [pt2, admin, "One of my favorite places on Earth."],
  [pt3, bob, "The W trek is legendary. Did you do the full circuit?"]
]

comments = comments_data.map do |entry, user, body|
  Comment.find_or_create_by!(
    journal_entry: entry, user: user, body: body
  )
end
log "Created #{Comment.count} comments"

# ---------------------------------------------------------------------------
# 6. Reactions
# ---------------------------------------------------------------------------

puts "\n--- Reactions ---"

reactions_data = [
  # On trips
  [japan, admin, "heart"], [japan, alice, "fire"],
  [japan, bob, "thumbsup"], [japan, dave, "tada"],
  [iceland, alice, "rocket"], [iceland, carol, "fire"],
  [iceland, bob, "heart"],
  [patagonia, carol, "heart"], [patagonia, alice, "thumbsup"],
  # On journal entries
  [jp1, alice, "heart"], [jp1, bob, "fire"], [jp1, dave, "thumbsup"],
  [jp4, admin, "heart"], [jp4, eve, "eyes"], [jp4, alice, "tada"],
  [ic1, admin, "fire"], [ic1, carol, "rocket"],
  [pt2, alice, "heart"], [pt2, bob, "fire"], [pt2, admin, "tada"],
  # On comments
  [comments[0], bob, "thumbsup"], [comments[0], dave, "heart"],
  [comments[2], admin, "fire"], [comments[2], alice, "thumbsup"],
  [comments[10], carol, "heart"]
]

reactions_data.each do |reactable, user, emoji|
  Reaction.find_or_create_by!(
    reactable: reactable, user: user, emoji: emoji
  )
end
log "Created #{Reaction.count} reactions"

# ---------------------------------------------------------------------------
# 7. Checklists
# ---------------------------------------------------------------------------

puts "\n--- Checklists ---"

def seed_checklist(trip:, name:, sections:)
  checklist = Checklist.find_or_create_by!(trip: trip, name: name)
  sections.each_with_index do |(section_name, items), si|
    section = ChecklistSection.find_or_create_by!(
      checklist: checklist, name: section_name
    ) do |s|
      s.position = si
    end
    items.each_with_index do |(content, done), ii|
      item = ChecklistItem.find_or_create_by!(
        checklist_section: section, content: content
      ) do |ci|
        ci.position = ii
        ci.completed = done
      end
      item.update!(completed: done) unless item.completed == done
    end
  end
end

seed_checklist(
  trip: japan, name: "Packing List",
  sections: {
    "Clothing" => [
      ["T-shirts", true], ["Light jacket", true],
      ["Rain gear", true], ["Comfortable walking shoes", true]
    ],
    "Electronics" => [
      ["Camera + lenses", true], ["Charger adapters (Type A)", true],
      ["Power bank", true]
    ],
    "Documents" => [
      ["Passport", true], ["JR Pass", true],
      ["Hotel confirmations", true]
    ]
  }
)

seed_checklist(
  trip: iceland, name: "Trip Essentials",
  sections: {
    "Gear" => [
      ["Thermal base layers", true], ["Waterproof jacket", true],
      ["Hiking boots", true], ["Crampons", false]
    ],
    "Supplies" => [
      ["Trail snacks", true], ["Water bottles", true],
      ["First aid kit", false], ["Sunscreen (yes, really)", false]
    ]
  }
)

seed_checklist(
  trip: barcelona, name: "Pre-Trip Checklist",
  sections: {
    "Bookings" => [
      ["Flights booked", true], ["Hotel reserved", true],
      ["Sagrada Familia tickets", false],
      ["Restaurant reservations", false]
    ],
    "Packing" => [
      ["Sunglasses", false], ["Lightweight clothes", false],
      ["Walking shoes", false]
    ]
  }
)

log "Created #{Checklist.count} checklists, #{ChecklistItem.count} items"

# ---------------------------------------------------------------------------
# 8. Access Requests
# ---------------------------------------------------------------------------

puts "\n--- Access Requests ---"

ar_pending = AccessRequest.find_or_create_by!(
  email: "pending-user@example.com"
)

ar_approved = AccessRequest.find_or_create_by!(
  email: "approved-user@example.com"
)
unless ar_approved.approved?
  ar_approved.update!(
    status: :approved, reviewed_by: admin,
    reviewed_at: 3.days.ago
  )
end

ar_rejected = AccessRequest.find_or_create_by!(
  email: "rejected-user@example.com"
)
unless ar_rejected.rejected?
  ar_rejected.update!(
    status: :rejected, reviewed_by: admin,
    reviewed_at: 5.days.ago
  )
end

log "Created #{AccessRequest.count} access requests"

# ---------------------------------------------------------------------------
# 9. Invitations
# ---------------------------------------------------------------------------

puts "\n--- Invitations ---"

inv_pending = Invitation.find_or_create_by!(
  email: "invited-new@example.com"
) do |inv|
  inv.inviter = admin
  inv.expires_at = 7.days.from_now
end

inv_accepted = Invitation.find_or_create_by!(
  email: "invited-joined@example.com"
) do |inv|
  inv.inviter = admin
  inv.expires_at = 7.days.ago
end
unless inv_accepted.accepted?
  inv_accepted.update!(
    status: :accepted, accepted_at: 5.days.ago
  )
end

inv_expired = Invitation.find_or_create_by!(
  email: "invited-expired@example.com"
) do |inv|
  inv.inviter = admin
  inv.expires_at = 2.days.ago
end
inv_expired.update!(status: :expired) unless inv_expired.expired?

log "Created #{Invitation.count} invitations"

# ---------------------------------------------------------------------------
# 10. Exports
# ---------------------------------------------------------------------------

puts "\n--- Exports ---"

exp_completed = Export.find_or_create_by!(
  trip: japan, user: admin, format: :markdown
)
unless exp_completed.completed?
  exp_completed.update!(status: :completed)
  unless exp_completed.file.attached?
    exp_completed.file.attach(
      io: StringIO.new("# Japan Spring Tour\n\nExported trip journal."),
      filename: "japan-spring-tour.zip",
      content_type: "application/zip"
    )
  end
end

Export.find_or_create_by!(
  trip: japan, user: admin, format: :epub
)

exp_failed = Export.find_or_create_by!(
  trip: patagonia, user: carol, format: :markdown
)
exp_failed.update!(status: :failed) unless exp_failed.failed?

log "Created #{Export.count} exports"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

puts "\n=== Seed Complete ==="
puts "  Users: #{User.count}"
puts "  Trips: #{Trip.count} " \
     "(#{Trip.group(:state).count.map { |s, c| "#{s}: #{c}" }.join(', ')})"
puts "  Memberships: #{TripMembership.count}"
puts "  Journal Entries: #{JournalEntry.count}"
puts "  Comments: #{Comment.count}"
puts "  Reactions: #{Reaction.count}"
puts "  Checklists: #{Checklist.count}"
puts "  Access Requests: #{AccessRequest.count}"
puts "  Invitations: #{Invitation.count}"
puts "  Exports: #{Export.count}"
puts ""
