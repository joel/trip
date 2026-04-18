# frozen_string_literal: true

class AccessRequest < ApplicationRecord
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_not_already_active
  validate :email_not_already_registered

  scope :pending, -> { where(status: :pending) }

  private

  def email_not_already_active
    return if email.blank?

    scope = self.class.where(email: email, status: %i[pending approved])
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    errors.add(:email, "already has a pending request or approved invitation")
  end

  def email_not_already_registered
    return if email.blank?
    return unless User.exists?(email: email)

    errors.add(:email, "is already registered — please sign in")
  end
end
