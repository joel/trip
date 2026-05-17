# frozen_string_literal: true

module Tools
  class AddJournalVideos < BaseTool
    description "Attach videos to a journal entry via HTTPS URLs " \
                "(max 3 per call, max 200MB and 3 min each, " \
                "mp4/quicktime/webm only). Transcoding is async."

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        urls: {
          type: "array",
          items: { type: "string" },
          description: "Video URLs to attach (HTTPS only, max 3)"
        }
      },
      required: %w[journal_entry_id urls]
    )

    def self.call(journal_entry_id:, urls:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)

      result = JournalEntries::AttachVideos.new.call(
        journal_entry: entry, urls: Array(urls)
      )

      case result
      in Dry::Monads::Success(updated)
        success_response(
          journal_entry_id: updated.id,
          attached: Array(urls).size,
          total_videos: updated.videos.count
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
