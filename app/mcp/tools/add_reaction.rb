# frozen_string_literal: true

module Tools
  class AddReaction < BaseTool
    description "Toggle an emoji reaction on a journal entry"

    input_schema(
      properties: {
        journal_entry_id: { type: "string", description: "Journal entry UUID" },
        emoji: { type: "string", description: "Unicode emoji to toggle" }
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
      text_error(e.message)
    rescue ActiveRecord::RecordNotFound
      text_error("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.format_result(result, emoji, entry_id)
      case result
      in Dry::Monads::Success(:removed)
        text_response(action: "removed", emoji: emoji, journal_entry_id: entry_id)
      in Dry::Monads::Success(reaction)
        text_response(action: "added", emoji: emoji, id: reaction.id, journal_entry_id: entry_id)
      in Dry::Monads::Failure(errors)
        msg = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.to_s
        text_error(msg)
      end
    end

    private_class_method def self.text_response(**data)
      MCP::Tool::Response.new([{ type: "text", text: data.to_json }])
    end

    private_class_method def self.text_error(message)
      MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
    end
  end
end
