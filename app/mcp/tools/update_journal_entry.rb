# frozen_string_literal: true

module Tools
  class UpdateJournalEntry < BaseTool
    description "Update an existing journal entry"

    input_schema(
      properties: {
        journal_entry_id: { type: "string", description: "Journal entry UUID" },
        name: { type: "string", description: "New entry title" },
        body: { type: "string", description: "New entry body (rich text)" },
        entry_date: { type: "string", description: "New date in YYYY-MM-DD format" },
        location_name: { type: "string", description: "New location name" },
        description: { type: "string", description: "New short summary" }
      },
      required: %w[journal_entry_id]
    )

    # rubocop:disable Metrics/ParameterLists -- MCP tool interface requires all input schema params
    def self.call(journal_entry_id:, name: nil, body: nil,
                  entry_date: nil, location_name: nil,
                  description: nil, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      params = { name: name, entry_date: entry_date,
                 location_name: location_name, description: description }.compact
      perform_update(entry, params, body)
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end
    # rubocop:enable Metrics/ParameterLists

    private_class_method def self.perform_update(entry, params, body)
      result = JournalEntries::Update.new.call(journal_entry: entry, params: params)
      case result
      in Dry::Monads::Success(updated)
        updated.update!(body: body) if body.present?
        data = { id: updated.id, name: updated.name, entry_date: updated.entry_date.to_s }
        MCP::Tool::Response.new([{ type: "text", text: data.to_json }])
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    end

    private_class_method def self.error_response(errors)
      message = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.to_s
      MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
    end
  end
end
