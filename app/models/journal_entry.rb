# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :trip
  belongs_to :author, class_name: "User"

  has_rich_text :body
  has_many_attached :images
  has_many :videos, -> { order(:position) },
           class_name: "JournalEntryVideo",
           inverse_of: :journal_entry, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many :journal_entry_subscriptions, dependent: :destroy
  has_many :subscribers, through: :journal_entry_subscriptions,
                         source: :user

  validates :name, presence: true
  validates :entry_date, presence: true

  scope :chronological, lambda {
    order(entry_date: :asc, created_at: :asc, id: :asc)
  }

  scope :reverse_chronological, lambda {
    order(entry_date: :desc, created_at: :desc, id: :desc)
  }
end
