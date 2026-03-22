# frozen_string_literal: true

module JournalEntries
  class Delete < BaseAction
    def call(journal_entry:)
      trip_id = journal_entry.trip_id
      entry_id = journal_entry.id
      yield destroy(journal_entry)
      yield emit_event(entry_id, trip_id)
      Success()
    end

    private

    def destroy(journal_entry)
      journal_entry.destroy!
      Success()
    end

    def emit_event(entry_id, trip_id)
      Rails.event.notify(
        "journal_entry.deleted",
        journal_entry_id: entry_id, trip_id: trip_id
      )
      Success()
    end
  end
end
