# frozen_string_literal: true

module Tools
  class UpdateComment < BaseTool
    description "Edit a comment's body (only on writable trips)"

    input_schema(
      properties: {
        comment_id: {
          type: "string", description: "Comment UUID"
        },
        body: {
          type: "string", description: "New comment text"
        }
      },
      required: %w[comment_id body]
    )

    def self.call(comment_id:, body:, _server_context: {})
      comment = Comment.find(comment_id)
      require_writable!(comment.journal_entry.trip)

      params = { body: body }.compact
      raise ToolError, "No updatable parameters provided" if params.empty?

      result = Comments::Update.new.call(comment: comment, params: params)

      case result
      in Dry::Monads::Success(updated)
        success_response(
          id: updated.id, body: updated.body,
          journal_entry_id: updated.journal_entry_id
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Comment not found: #{comment_id}")
    end
  end
end
