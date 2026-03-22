# frozen_string_literal: true

FactoryBot.define do
  factory :checklist_item do
    checklist_section
    content { "T-shirts" }
  end
end
