# frozen_string_literal: true

module Tools
  class UploadJournalVideos < BaseTool
    description "Upload short videos to a journal entry via " \
                "base64-encoded data (max 2 per call, max 50MB and " \
                "3 min each, mp4/quicktime/webm). Use add_journal_" \
                "videos with a URL for anything but a short clip."

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        videos: {
          type: "array",
          items: {
            type: "object",
            properties: {
              data: {
                type: "string",
                description: "Base64-encoded video data"
              },
              filename: {
                type: "string",
                description: "Original filename (optional)"
              }
            },
            required: %w[data]
          },
          description: "Videos to upload (max 2 per call, max 50MB)"
        }
      },
      required: %w[journal_entry_id videos]
    )

    def self.call(journal_entry_id:, videos:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)

      result = JournalEntries::UploadVideos.new.call(
        journal_entry: entry, videos: Array(videos)
      )

      case result
      in Dry::Monads::Success(updated)
        success_response(
          journal_entry_id: updated.id,
          attached: Array(videos).size,
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
