# frozen_string_literal: true

module Tools
  class AddReaction < BaseTool
    description "Toggle an emoji reaction on a journal entry"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        emoji: {
          type: "string",
          description: "Emoji name to toggle",
          enum: Reaction::ALLOWED_EMOJIS
        }
      },
      required: %w[journal_entry_id emoji]
    )

    def self.call(journal_entry_id:, emoji:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_commentable!(entry.trip)
      result = Reactions::Toggle.new.call(
        reactable: entry, user: resolve_jack_user, emoji: emoji
      )
      format_result(result, emoji, journal_entry_id)
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response(
        "Journal entry not found: #{journal_entry_id}"
      )
    end

    private_class_method def self.format_result(result, emoji, eid)
      case result
      in Dry::Monads::Success(:removed)
        success_response(
          action: "removed", emoji: emoji,
          journal_entry_id: eid
        )
      in Dry::Monads::Success(reaction)
        success_response(
          action: "added", emoji: emoji,
          id: reaction.id, journal_entry_id: eid
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    end
  end
end
