# frozen_string_literal: true

FactoryBot.define do
  factory :checklist do
    trip
    name { "Packing List" }
  end
end
