# frozen_string_literal: true

FactoryBot.define do
  factory :checklist_section do
    checklist
    name { "Clothing" }
  end
end
