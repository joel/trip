# frozen_string_literal: true

module Tools
  class CreateComment < BaseTool
    description "Add a comment to a journal entry"

    input_schema(
      properties: {
        journal_entry_id: { type: "string", description: "Journal entry UUID" },
        body: { type: "string", description: "Comment text" },
        telegram_message_id: { type: "string", description: "Telegram message ID for idempotency" }
      },
      required: %w[journal_entry_id body]
    )

    def self.call(journal_entry_id:, body:,
                  telegram_message_id: nil, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)

      if telegram_message_id.present?
        existing = entry.comments.find_by(
          telegram_message_id: telegram_message_id
        )
        return success_response(existing) if existing
      end

      user = resolve_jack_user
      params = { body: body, telegram_message_id: telegram_message_id }.compact

      result = Comments::Create.new.call(
        params: params, journal_entry: entry, user: user
      )

      case result
      in Dry::Monads::Success(comment)
        success_response(comment)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.success_response(comment)
      MCP::Tool::Response.new([{
                                type: "text",
                                text: { id: comment.id, body: comment.body,
                                        journal_entry_id: comment.journal_entry_id }.to_json
                              }])
    end

    private_class_method def self.error_response(errors)
      message = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.to_s
      MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
    end
  end
end
