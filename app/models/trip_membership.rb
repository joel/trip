# frozen_string_literal: true

class TripMembership < ApplicationRecord
  enum :role, { contributor: 0, viewer: 1 }

  belongs_to :trip
  belongs_to :user

  validates :user_id, uniqueness: { scope: :trip_id }
end
