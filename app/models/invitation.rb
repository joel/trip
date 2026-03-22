# frozen_string_literal: true

class Invitation < ApplicationRecord
  enum :status, { pending: 0, accepted: 1, expired: 2 }

  belongs_to :inviter, class_name: "User"

  has_secure_token :token

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :expires_at, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :valid_tokens, -> { pending.where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def accept!
    update!(status: :accepted, accepted_at: Time.current)
  end
end
