# frozen_string_literal: true

FactoryBot.define do
  factory :checklist_item, class: "Checklists::Item" do
    checklist_section
    content { "T-shirts" }
  end
end
