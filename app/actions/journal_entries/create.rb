# frozen_string_literal: true

module JournalEntries
  class Create < BaseAction
    def call(params:, trip:, user:)
      entry = yield persist(params, trip, user)
      yield subscribe_trip_members(entry)
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

    def subscribe_trip_members(entry)
      user_ids = entry.trip.members
                      .where.not("email LIKE ?", "%@system.local")
                      .pluck(:id)
      user_ids |= [entry.author_id] unless system_actor?(entry.author)
      user_ids.each do |uid|
        entry.journal_entry_subscriptions
             .find_or_create_by!(user_id: uid)
      end
      Success()
    end

    def system_actor?(user)
      user&.email&.end_with?("@system.local")
    end

    def emit_event(entry)
      Rails.event.notify(
        "journal_entry.created",
        journal_entry_id: entry.id,
        trip_id: entry.trip_id,
        actor_id: entry.author_id
      )
      Success()
    end
  end
end
