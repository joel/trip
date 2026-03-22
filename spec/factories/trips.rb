# frozen_string_literal: true

FactoryBot.define do
  factory :trip do
    name { "Test Trip" }
    created_by factory: %i[user superadmin]

    trait :started do
      state { :started }
    end

    trait :finished do
      state { :finished }
    end

    trait :cancelled do
      state { :cancelled }
    end

    trait :archived do
      state { :archived }
    end

    trait :with_dates do
      start_date { Date.current }
      end_date { 7.days.from_now.to_date }
    end
  end
end
