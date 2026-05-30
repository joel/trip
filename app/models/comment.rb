# frozen_string_literal: true

class Comment < ApplicationRecord
  include Discard::Model

  belongs_to :journal_entry
  belongs_to :user

  has_many :reactions, as: :reactable, dependent: :destroy

  validates :body, presence: true

  default_scope -> { kept }

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
end
