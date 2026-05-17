# frozen_string_literal: true

# A first-class video attached to a JournalEntry. The agent/web form
# attaches `source`; ProcessJournalVideosJob transcodes it to a
# web-friendly `web` rendition + a `poster` frame and records
# duration/dimensions, gating playback on `status`.
class JournalEntryVideo < ApplicationRecord
  belongs_to :journal_entry

  has_one_attached :source
  has_one_attached :web
  has_one_attached :poster

  enum :status,
       { pending: 0, processing: 1, ready: 2, failed: 3 },
       default: :pending

  scope :ready, -> { where(status: :ready) }
end
