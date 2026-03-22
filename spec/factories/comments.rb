# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    journal_entry
    user
    body { "Great post!" }
  end
end
