# frozen_string_literal: true

class Agent < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9_-]+\z/

  belongs_to :user

  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: SLUG_FORMAT }
  validates :name, presence: true
  validates :user_id, uniqueness: true

  def self.by_slug(slug)
    find_by("LOWER(slug) = ?", slug.to_s.downcase)
  end
end
