# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  include Discard::Model

  belongs_to :trip
  belongs_to :author, class_name: "User"

  has_rich_text :body
  has_many_attached :images
  has_many :videos, -> { order(:position) },
           class_name: "JournalEntryVideo",
           inverse_of: :journal_entry, dependent: :destroy
  has_many :comments, dependent: :destroy
  # Phase 26: retention records for soft-removed images (see DetachedAttachment).
  has_many :detached_attachments, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many :journal_entry_subscriptions, dependent: :destroy
  has_many :subscribers, through: :journal_entry_subscriptions,
                         source: :user

  # Version the title. `only: [:name]` already excludes discarded_at, so a
  # discard never creates a title version. The rich-text *content* (body) is a
  # separate ActionText::RichText record, versioned via the paper_trail
  # initializer (config/initializers/paper_trail_action_text.rb).
  has_paper_trail only: %i[name], on: %i[create update]

  validates :name, presence: true
  validates :entry_date, presence: true

  default_scope -> { kept }

  # Cascade discard down to comments and videos. Restore is parent-only by
  # design — restoring the entry brings back the entry + its images, but
  # comments/videos discarded by this cascade are restored individually from
  # the Activity feed (Phase 26, mirroring Phase 25).
  after_discard do
    comments.kept.find_each(&:discard)
    videos.kept.find_each(&:discard)
  end

  scope :chronological, lambda {
    order(entry_date: :asc, created_at: :asc, id: :asc)
  }

  scope :reverse_chronological, lambda {
    order(entry_date: :desc, created_at: :desc, id: :desc)
  }
end
