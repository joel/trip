# frozen_string_literal: true

module Tools
  class ListComments < BaseTool
    description "List comments on a journal entry with pagination"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        limit: {
          type: "integer",
          description: "Max comments to return (default 10, max 100)"
        },
        offset: {
          type: "integer",
          description: "Number of comments to skip (default 0)"
        }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, limit: 10, offset: 0,
                  _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      limit = limit.to_i.clamp(1, 100)
      offset = [offset.to_i, 0].max

      scope = entry.comments.chronological.includes(:user)

      success_response(
        comments: scope.offset(offset).limit(limit).map { |c| serialize(c) },
        total: entry.comments.count, limit: limit, offset: offset
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.serialize(comment)
      {
        id: comment.id, body: comment.body,
        author_email: comment.user.email,
        author_name: comment.user.name,
        created_at: comment.created_at.iso8601
      }
    end
  end
end
