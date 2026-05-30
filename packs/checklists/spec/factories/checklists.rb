# frozen_string_literal: true

FactoryBot.define do
  factory :checklist, class: "Checklists::Checklist" do
    trip
    name { "Packing List" }
  end
end
