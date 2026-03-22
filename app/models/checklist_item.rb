# frozen_string_literal: true

class ChecklistItem < ApplicationRecord
  belongs_to :checklist_section

  validates :content, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def toggle!
    update!(completed: !completed)
  end
end
