# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :user

  has_many :reactions, as: :reactable, dependent: :destroy

  validates :body, presence: true

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
end
