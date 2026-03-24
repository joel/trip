# frozen_string_literal: true

module Tools
  class CreateComment < BaseTool
    description "Add a comment to a journal entry"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        body: { type: "string", description: "Comment text" },
        telegram_message_id: {
          type: "string",
          description: "Telegram message ID for idempotency"
        }
      },
      required: %w[journal_entry_id body]
    )

    def self.call(journal_entry_id:, body:,
                  telegram_message_id: nil, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_commentable!(entry.trip)
      idempotent = find_existing(entry, telegram_message_id)
      return comment_response(idempotent) if idempotent

      create_comment(entry, body, telegram_message_id)
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotUnique
      existing = entry.comments.find_by!(
        telegram_message_id: telegram_message_id
      )
      comment_response(existing)
    rescue ActiveRecord::RecordNotFound
      error_response(
        "Journal entry not found: #{journal_entry_id}"
      )
    end

    private_class_method def self.find_existing(entry, msg_id)
      return if msg_id.blank?

      entry.comments.find_by(telegram_message_id: msg_id)
    end

    private_class_method def self.create_comment(entry, body, msg_id)
      params = { body: body, telegram_message_id: msg_id }.compact
      result = Comments::Create.new.call(
        params: params, journal_entry: entry,
        user: resolve_jack_user
      )
      case result
      in Dry::Monads::Success(comment)
        comment_response(comment)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    end

    private_class_method def self.comment_response(comment)
      success_response(
        id: comment.id, body: comment.body,
        journal_entry_id: comment.journal_entry_id
      )
    end
  end
end
