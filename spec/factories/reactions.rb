# frozen_string_literal: true

FactoryBot.define do
  factory :reaction do
    reactable factory: %i[journal_entry]
    user
    emoji { "thumbsup" }
  end
end
