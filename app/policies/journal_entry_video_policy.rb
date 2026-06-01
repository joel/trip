# frozen_string_literal: true

# Authorises per-item video removal/restore (Phase 26). Mirrors
# JournalEntryPolicy#destroy?/#restore? on the video's parent entry: the entry
# author (a contributor) or a superadmin may remove/restore, and only while the
# trip is writable. The entry is loaded `with_discarded` so authorisation never
# NPEs when checking a video whose entry was discarded.
class JournalEntryVideoPolicy < ApplicationPolicy
  def destroy?
    (superadmin? || (contributor? && own_entry?)) && entry&.trip&.writable?
  end

  # Mirrors destroy? — whoever may remove may restore.
  def restore?
    destroy?
  end

  private

  def entry
    return @entry if defined?(@entry)

    @entry = JournalEntry.with_discarded.find_by(id: record.journal_entry_id)
  end

  def trip_membership
    return unless user && entry

    entry.trip.trip_memberships.find_by(user: user)
  end

  def contributor?
    trip_membership&.contributor?
  end

  def own_entry?
    entry&.author_id == user&.id
  end
end
