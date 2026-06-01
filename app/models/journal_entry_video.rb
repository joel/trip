# frozen_string_literal: true

# A first-class video attached to a JournalEntry. The agent/web form
# attaches `source`; ProcessJournalVideosJob transcodes it to a
# web-friendly `web` rendition + a `poster` frame and records
# duration/dimensions, gating playback on `status`.
class JournalEntryVideo < ApplicationRecord
  include Discard::Model

  belongs_to :journal_entry

  has_one_attached :source
  has_one_attached :web
  has_one_attached :poster

  enum :status,
       { pending: 0, processing: 1, ready: 2, failed: 3 },
       default: :pending

  # Discarded videos never leak into any read path (cards, gallery, lightbox,
  # `ready`). Discard keeps the row — so its source/web/poster attachments stay,
  # the blobs are never orphaned, and OrphanBlobsCleanupJob ignores them.
  # Restore is parent-only by design (Phase 26, mirroring Phase 25). Use
  # `with_discarded` on restore/feed paths. See prompts/Phase 26 §5.1.
  default_scope -> { kept }

  scope :ready, -> { where(status: :ready) }

  # When the transcoding job flips status (pending → ready / failed),
  # push a Turbo Stream that replaces the placeholder with the right
  # VideoPlayer rendering on every open viewer of the journal entry —
  # no manual refresh (#177). Subscribers are added by
  # JournalEntryCard's `turbo_stream_from @entry, :videos`. The Phlex
  # component is rendered via ApplicationController.render so url_for
  # + routes work outside a request cycle.
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def broadcast_status_change
    # layout: false — render just the component, not the full app
    # layout (which expects a current_user context that doesn't
    # exist in the after_update_commit callback chain).
    html = ApplicationController.render(
      Components::VideoPlayer.new(video: self), layout: false
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      journal_entry, :videos,
      target: ActionView::RecordIdentifier.dom_id(self),
      html: html
    )
  end
end
