# frozen_string_literal: true

class NotifyEntryCreatedJob < ApplicationJob
  queue_as :default

  def perform(journal_entry_id, actor_id)
    entry = JournalEntry.find_by(id: journal_entry_id)
    return unless entry

    entry.trip.members.where.not(id: actor_id).find_each do |member|
      CreateNotificationJob.perform_later(
        notifiable_type: "JournalEntry",
        notifiable_id: entry.id,
        recipient_id: member.id,
        actor_id: actor_id,
        event_type: "entry_created"
      )
      NotificationMailer.entry_created(
        entry.id, member.id
      ).deliver_later
    end
  end
end
