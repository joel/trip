# frozen_string_literal: true

FactoryBot.define do
  factory :journal_entry do
    trip
    author factory: %i[user]
    name { "Day 1" }
    entry_date { Date.current }

    trait :with_location do
      location_name { "Paris, France" }
      latitude { 48.8566 }
      longitude { 2.3522 }
    end

    trait :with_body do
      body { "Sample journal entry content with <strong>bold text</strong>." }
    end
  end
end
