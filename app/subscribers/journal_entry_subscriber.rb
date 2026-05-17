# frozen_string_literal: true

class JournalEntrySubscriber
  def emit(event)
    entry_id = event[:payload][:journal_entry_id]
    case event[:name]
    when "journal_entry.created", "journal_entry.images_added"
      Rails.logger.info("#{event[:name]}: #{entry_id}")
      ProcessJournalImagesJob.perform_later(entry_id)
    when "journal_entry.videos_added"
      Rails.logger.info("#{event[:name]}: #{entry_id}")
      ProcessJournalVideosJob.perform_later(entry_id)
    end
  end
end
