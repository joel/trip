# frozen_string_literal: true

FactoryBot.define do
  factory :access_request do
    email { generate(:email) }
    status { :pending }

    trait :approved do
      status { :approved }
      reviewed_by factory: %i[user], strategy: :create
      reviewed_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
      reviewed_by factory: %i[user], strategy: :create
      reviewed_at { Time.current }
    end
  end
end
