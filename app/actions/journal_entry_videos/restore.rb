# frozen_string_literal: true

module JournalEntryVideos
  # Restores a soft-removed video: undiscards it into the kept scope and emits
  # "journal_entry_video.restored". Resolve the video via `with_discarded`
  # first (the default kept scope hides it); its parent entry must be kept for
  # the video to be visible once restored. Returns Failure(message) if it is
  # not discarded.
  class Restore < BaseAction
    def call(video:)
      entry = JournalEntry.with_discarded.find(video.journal_entry_id)
      yield restore(video)
      yield emit_event(video, entry)
      Success(video)
    end

    private

    def restore(video)
      video.undiscard!
      Success()
    rescue Discard::RecordNotUndiscarded => e
      Failure(e.message)
    end

    def emit_event(video, entry)
      Rails.event.notify(
        "journal_entry_video.restored",
        journal_entry_video_id: video.id,
        journal_entry_id: entry.id,
        trip_id: entry.trip_id
      )
      Success()
    end
  end
end
