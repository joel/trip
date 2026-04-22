# frozen_string_literal: true

FactoryBot.define do
  sequence(:email) { |n| "user#{n}@example.com" }

  sequence(:system_actor_email) { |n| "agent#{n}@system.local" }

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

    trait :system_actor do
      email { generate(:system_actor_email) }
      name { "System Actor" }
    end
  end
end
