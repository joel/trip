# frozen_string_literal: true

FactoryBot.define do
  sequence(:agent_slug) { |n| "agent#{n}" }

  factory :agent do
    slug { generate(:agent_slug) }
    name { slug.capitalize }

    user do
      association(:user, :system_actor, name: name)
    end
  end
end
