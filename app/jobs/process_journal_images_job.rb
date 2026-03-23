# frozen_string_literal: true

class ProcessJournalImagesJob < ApplicationJob
  queue_as :default

  def perform(journal_entry_id)
    entry = JournalEntry.find_by(id: journal_entry_id)
    return unless entry&.images&.attached?

    entry.images.each do |image|
      image.variant(resize_to_limit: [800, 600]).processed
      image.variant(resize_to_limit: [200, 200]).processed
    end
  end
end
