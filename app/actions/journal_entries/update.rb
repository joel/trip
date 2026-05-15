# frozen_string_literal: true

module JournalEntries
  class Update < BaseAction
    def call(journal_entry:, params:)
      yield persist(journal_entry, params)
      yield emit_event(journal_entry)
      Success(journal_entry)
    end

    private

    def persist(journal_entry, params)
      journal_entry.update!(params)
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(journal_entry)
      Rails.event.notify(
        "journal_entry.updated",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        changes: journal_entry.saved_changes.except("created_at", "updated_at")
      )
      Success()
    end
  end
end
