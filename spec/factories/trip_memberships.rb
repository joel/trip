# frozen_string_literal: true

FactoryBot.define do
  factory :trip_membership do
    trip
    user
    role { :contributor }

    trait :viewer do
      role { :viewer }
    end
  end
end
