# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    journal_entry
    user
    body { "Great post!" }

    trait :discarded do
      after(:create, &:discard!)
    end
  end
end
