# frozen_string_literal: true

FactoryBot.define do
  factory :export do
    trip
    user factory: %i[user superadmin]
    format { :markdown }

    trait :epub do
      format { :epub }
    end

    trait :processing do
      status { :processing }
    end

    trait :completed do
      status { :completed }
    end

    trait :failed do
      status { :failed }
    end
  end
end
