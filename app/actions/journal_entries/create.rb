# frozen_string_literal: true

module JournalEntries
  class Create < BaseAction
    def call(params:, trip:, user:)
      entry = yield persist(params, trip, user)
      yield emit_event(entry)
      Success(entry)
    end

    private

    def persist(params, trip, user)
      entry = trip.journal_entries.create!(
        params.merge(author: user)
      )
      Success(entry)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(entry)
      Rails.event.notify(
        "journal_entry.created",
        journal_entry_id: entry.id, trip_id: entry.trip_id
      )
      Success()
    end
  end
end
