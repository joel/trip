# frozen_string_literal: true

FactoryBot.define do
  sequence(:audit_event_uid) { |n| "evt-#{n}-#{SecureRandom.hex(4)}" }

  factory :audit_log do
    trip
    actor factory: %i[user]
    actor_label { "Test Actor" }
    action { "journal_entry.created" }
    auditable factory: %i[journal_entry]
    summary { "Test Actor created journal entry" }
    metadata { {} }
    source { :web }
    request_id { SecureRandom.uuid }
    event_uid { generate(:audit_event_uid) }
    occurred_at { Time.current }

    trait :app_wide do
      trip { nil }
      auditable { nil }
      action { "invitation.sent" }
      summary { "An invitation was sent" }
    end

    trait :low_signal do
      action { "reaction.created" }
      auditable factory: %i[reaction]
      summary { "Test Actor reacted" }
    end

    trait :with_changes do
      action { "trip.updated" }
      auditable factory: %i[trip]
      metadata { { "changes" => { "name" => ["Old Name", "New Name"] } } }
      summary { 'Test Actor updated trip — Name: "Old Name" → "New Name"' }
    end

    trait :system_source do
      actor { nil }
      actor_label { "System" }
      source { :system }
    end
  end
end
