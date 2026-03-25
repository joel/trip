# frozen_string_literal: true

module Tools
  class UploadJournalImages < BaseTool
    description "Upload images to a journal entry via base64-encoded " \
                "data (max 5 per call, max 10MB each, " \
                "jpeg/png/webp/gif only)"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        images: {
          type: "array",
          items: {
            type: "object",
            properties: {
              data: {
                type: "string",
                description: "Base64-encoded image data"
              },
              filename: {
                type: "string",
                description: "Original filename (optional)"
              }
            },
            required: %w[data]
          },
          description: "Images to upload " \
                       "(max 5 per call, max 10MB each, " \
                       "jpeg/png/webp/gif)"
        }
      },
      required: %w[journal_entry_id images]
    )

    def self.call(journal_entry_id:, images:,
                  _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)

      result = JournalEntries::UploadImages.new.call(
        journal_entry: entry, images: Array(images)
      )

      case result
      in Dry::Monads::Success(updated)
        success_response(
          journal_entry_id: updated.id,
          attached: Array(images).size,
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
