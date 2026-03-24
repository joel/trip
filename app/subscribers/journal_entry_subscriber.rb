# frozen_string_literal: true

class JournalEntrySubscriber
  def emit(event)
    case event[:name]
    when "journal_entry.created", "journal_entry.images_added"
      Rails.logger.info(
        "#{event[:name]}: " \
        "#{event[:payload][:journal_entry_id]}"
      )
      ProcessJournalImagesJob.perform_later(
        event[:payload][:journal_entry_id]
      )
    end
  end
end
