# frozen_string_literal: true

class Export < ApplicationRecord
  enum :format, { markdown: 0, epub: 1 }
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  belongs_to :trip
  belongs_to :user

  has_one_attached :file

  validates :format, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
