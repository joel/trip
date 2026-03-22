# frozen_string_literal: true

class ChecklistSection < ApplicationRecord
  belongs_to :checklist

  has_many :checklist_items, -> { order(position: :asc) },
           inverse_of: :checklist_section, dependent: :destroy

  validates :name, presence: true
end
