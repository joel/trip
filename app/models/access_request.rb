# frozen_string_literal: true

class AccessRequest < ApplicationRecord
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  belongs_to :reviewed_by, class_name: "User", optional: true

  before_validation :normalize_email

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_not_already_active, on: :create
  validate :email_not_already_registered, on: :create

  scope :pending, -> { where(status: :pending) }

  private

  def normalize_email
    self.email = email.to_s.downcase.strip.presence
  end

  def email_not_already_active
    return if email.blank?
    return unless self.class.exists?(email: email, status: %i[pending approved])

    errors.add(:email, "already has a pending request or approved invitation")
  end

  def email_not_already_registered
    return if email.blank?
    return unless User.exists?(["LOWER(email) = ?", email])

    errors.add(:email, "is already registered — please sign in")
  end
end
