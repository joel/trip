# frozen_string_literal: true

FactoryBot.define do
  sequence(:agent_slug) { |n| "agent#{n}" }

  factory :agent do
    slug { generate(:agent_slug) }
    name { slug.capitalize }
    user factory: %i[user system_actor]
  end
end
