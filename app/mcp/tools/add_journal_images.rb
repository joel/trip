# frozen_string_literal: true

module Tools
  class AddJournalImages < BaseTool
    description "Attach images to a journal entry via HTTPS URLs " \
                "(max 5 per call, max 10MB each, " \
                "jpeg/png/webp/gif only)"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        urls: {
          type: "array",
          items: { type: "string" },
          description: "Image URLs to attach " \
                       "(HTTPS only, max 5)"
        }
      },
      required: %w[journal_entry_id urls]
    )

    def self.call(journal_entry_id:, urls:,
                  _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)

      result = JournalEntries::AttachImages.new.call(
        journal_entry: entry, urls: Array(urls)
      )

      case result
      in Dry::Monads::Success(updated)
        success_response(
          journal_entry_id: updated.id,
          attached: Array(urls).size,
          total_images: updated.images.count
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response(
        "Journal entry not found: #{journal_entry_id}"
      )
    end
  end
end
