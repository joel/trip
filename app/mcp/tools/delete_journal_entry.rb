# frozen_string_literal: true

module Tools
  class DeleteJournalEntry < BaseTool
    description "Delete a journal entry (only on writable trips)"

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
      require_writable!(entry.trip)

      result = JournalEntries::Delete.new.call(journal_entry: entry)

      case result
      in Dry::Monads::Success()
        success_response(deleted: true, id: journal_entry_id)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end
  end
end
