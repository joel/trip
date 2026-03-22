# frozen_string_literal: true

class Checklist < ApplicationRecord
  belongs_to :trip

  has_many :checklist_sections, -> { order(position: :asc) },
           inverse_of: :checklist, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
