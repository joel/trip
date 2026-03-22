# frozen_string_literal: true

class AccessRequest < ApplicationRecord
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :pending, -> { where(status: :pending) }
end
