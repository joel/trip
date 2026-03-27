# frozen_string_literal: true

# Source: https://github.com/rails/rails/blob/8-0-stable/activerecord/lib/rails/generators/active_record/model/templates/model.rb.tt
class User < ApplicationRecord
  include Roleable

  has_many :trip_memberships, dependent: :destroy
  has_many :trips, through: :trip_memberships
  has_many :created_trips, class_name: "Trip",
                           foreign_key: :created_by_id,
                           dependent: :restrict_with_error,
                           inverse_of: :created_by
  has_many :journal_entries, foreign_key: :author_id,
                             dependent: :restrict_with_error,
                             inverse_of: :author
  has_many :comments, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :reactions, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id,
                           dependent: :destroy,
                           inverse_of: :recipient
  has_many :journal_entry_subscriptions, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
end
