# frozen_string_literal: true

FactoryBot.define do
  sequence(:email) { |n| "user#{n}@example.com" }

  factory :user do
    name { "MyString" }
    email { generate(:email) }

    trait :superadmin do
      roles { [:superadmin] }
    end

    trait :contributor do
      roles { [:contributor] }
    end

    trait :viewer do
      roles { [:viewer] }
    end
  end
end
