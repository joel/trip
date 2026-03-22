# frozen_string_literal: true

FactoryBot.define do
  factory :invitation do
    inviter factory: %i[user superadmin]
    email { generate(:email) }
    expires_at { 7.days.from_now }

    trait :accepted do
      status { :accepted }
      accepted_at { Time.current }
    end

    trait :expired_token do
      expires_at { 1.day.ago }
    end
  end
end
