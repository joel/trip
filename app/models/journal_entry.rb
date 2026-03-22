# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :trip
  belongs_to :author, class_name: "User"

  has_rich_text :body
  has_many_attached :images
  has_many :comments, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy

  validates :name, presence: true
  validates :entry_date, presence: true

  scope :chronological, lambda {
    order(entry_date: :asc, created_at: :asc, id: :asc)
  }
end
