# frozen_string_literal: true

FactoryBot.define do
  factory :journal_entry_subscription do
    user
    journal_entry
  end
end
