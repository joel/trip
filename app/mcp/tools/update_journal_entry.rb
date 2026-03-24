# frozen_string_literal: true

module Tools
  class UpdateJournalEntry < BaseTool
    description "Update an existing journal entry"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        name: { type: "string", description: "New entry title" },
        body: {
          type: "string",
          description: "New entry body (rich text)"
        },
        entry_date: {
          type: "string",
          description: "New date in YYYY-MM-DD format"
        },
        location_name: {
          type: "string", description: "New location name"
        },
        description: {
          type: "string", description: "New short summary"
        }
      },
      required: %w[journal_entry_id]
    )

    # rubocop:disable Metrics/ParameterLists
    def self.call(journal_entry_id:, name: nil, body: nil,
                  entry_date: nil, location_name: nil,
                  description: nil, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)
      params = { name: name, entry_date: entry_date,
                 location_name: location_name,
                 description: description }.compact
      if params.empty? && body.nil?
        raise ToolError,
              "No updatable parameters provided"
      end

      perform_update(entry, params, body)
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response(
        "Journal entry not found: #{journal_entry_id}"
      )
    end
    # rubocop:enable Metrics/ParameterLists

    private_class_method def self.perform_update(entry, params, body)
      result = JournalEntries::Update.new.call(
        journal_entry: entry, params: params
      )
      case result
      in Dry::Monads::Success(updated)
        updated.update!(body: body) if body.present?
        success_response(
          id: updated.id, name: updated.name,
          entry_date: updated.entry_date.to_s
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    end
  end
end
