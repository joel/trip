# frozen_string_literal: true

module Tools
  class GetJournalEntry < BaseTool
    description "Get a single journal entry by ID with full body, " \
                "image URLs, and counts"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string", description: "Journal entry UUID"
        }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)

      success_response(
        id: entry.id, name: entry.name,
        body: entry.body.to_s,
        entry_date: entry.entry_date.to_s,
        location_name: entry.location_name,
        description: entry.description,
        trip_id: entry.trip_id,
        comments_count: entry.comments.count,
        reactions_count: entry.reactions.count,
        image_urls: entry.images.map { |img| blob_url(img) }
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.blob_url(blob)
      Rails.application.routes.url_helpers.rails_blob_url(
        blob, host: ENV.fetch("APP_HOST", "localhost")
      )
    end
  end
end
