# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    notifiable factory: %i[journal_entry]
    recipient factory: %i[user]
    actor factory: %i[user]
    event_type { :entry_created }

    trait :member_added do
      notifiable factory: %i[trip_membership]
      event_type { :member_added }
    end

    trait :comment_added do
      notifiable factory: %i[comment]
      event_type { :comment_added }
    end

    trait :read do
      read_at { Time.current }
    end
  end
end
