# frozen_string_literal: true

module JournalEntries
  class Restore < BaseAction
    def call(journal_entry:)
      yield restore(journal_entry)
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

    def emit_event(journal_entry)
      Rails.event.notify(
        "journal_entry.restored",
        journal_entry_id: journal_entry.id, trip_id: journal_entry.trip_id
      )
      Success()
    end
  end
end
