# frozen_string_literal: true

module Tools
  class DeleteComment < BaseTool
    description "Delete a comment (only on commentable trips)"

    input_schema(
      properties: {
        comment_id: {
          type: "string", description: "Comment UUID"
        }
      },
      required: %w[comment_id]
    )

    def self.call(comment_id:, _server_context: {})
      comment = Comment.find(comment_id)
      require_commentable!(comment.journal_entry.trip)

      result = Comments::Delete.new.call(comment: comment)

      case result
      in Dry::Monads::Success()
        success_response(deleted: true, id: comment_id)
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
