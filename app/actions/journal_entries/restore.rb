# frozen_string_literal: true

module JournalEntries
  # Restores a soft-deleted journal entry: undiscards it into the kept scope,
  # cascade-restores the videos that were discarded as part of *this* deletion,
  # and emits "journal_entry.restored". Load the entry via `with_discarded`
  # first (the default kept scope hides it). Returns Failure(message) if it is
  # not discarded.
  #
  # Cascade-restore is scoped to **media** (videos): images ride along on the
  # surviving entry row, but videos are discarded as separate rows by the entry
  # cascade and would otherwise stay hidden with no recovery path (release-scan
  # finding #1). Comments remain parent-only (Phase 25 behaviour, unchanged).
  class Restore < BaseAction
    def call(journal_entry:)
      # Capture before undiscard! clears it: videos discarded at/after this
      # moment were discarded by THIS entry's cascade; earlier ones were
      # removed individually and must stay removed.
      cascade_cutoff = journal_entry.discarded_at
      yield restore(journal_entry)
      restore_cascaded_videos(journal_entry, cascade_cutoff)
      yield emit_event(journal_entry)
      Success(journal_entry)
    end

    private

    def restore(journal_entry)
      journal_entry.undiscard!
      Success()
    rescue Discard::RecordNotUndiscarded => e
      Failure(e.message)
    end

    # Best-effort: a video that can't be restored must not fail the entry
    # restore. Routed through the video Restore action so each emits
    # journal_entry_video.restored (keeps the Activity feed accurate).
    def restore_cascaded_videos(journal_entry, cutoff)
      return unless cutoff

      journal_entry.videos.with_discarded
                   .where(discarded_at: cutoff..)
                   .find_each do |video|
        JournalEntryVideos::Restore.new.call(video:)
      end
    end

    def emit_event(journal_entry)
      Rails.event.notify(
        "journal_entry.restored",
        journal_entry_id: journal_entry.id, trip_id: journal_entry.trip_id
      )
      Success()
    end
  end
end
