# frozen_string_literal: true

module Tools
  class ListReactions < BaseTool
    description "List emoji reactions on a journal entry"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      reactions = entry.reactions.includes(:user).order(created_at: :asc)

      success_response(
        reactions: reactions.map { |r| serialize(r) },
        total: reactions.size
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.serialize(reaction)
      {
        id: reaction.id, emoji: reaction.emoji,
        user_email: reaction.user.email,
        user_name: reaction.user.name
      }
    end
  end
end
