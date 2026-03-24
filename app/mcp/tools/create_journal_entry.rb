# frozen_string_literal: true

module Tools
  class CreateJournalEntry < BaseTool
    description "Create a journal entry for a trip"

    input_schema(
      properties: {
        trip_id: { type: "string", description: "Trip UUID (optional if exactly one trip is started)" },
        name: { type: "string", description: "Entry title" },
        body: { type: "string", description: "Entry body (rich text)" },
        entry_date: { type: "string", description: "Date in YYYY-MM-DD format" },
        location_name: { type: "string", description: "Human-readable location" },
        description: { type: "string", description: "Short summary" },
        actor_type: { type: "string", description: "Actor type for attribution", default: "Jack" },
        actor_id: { type: "string", description: "Actor identifier", default: "jack" },
        telegram_message_id: { type: "string", description: "Telegram message ID for idempotency" }
      },
      required: %w[name entry_date]
    )

    # rubocop:disable Metrics/ParameterLists -- MCP tool interface requires all input schema params
    def self.call(name:, entry_date:, trip_id: nil, body: nil,
                  location_name: nil, description: nil,
                  actor_type: "Jack", actor_id: "jack",
                  telegram_message_id: nil, _server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)
      idempotent_check(trip, telegram_message_id) || create_entry(
        trip: trip, name: name, entry_date: entry_date, body: body,
        location_name: location_name, description: description,
        actor_type: actor_type, actor_id: actor_id,
        telegram_message_id: telegram_message_id
      )
    rescue ToolError => e
      error_response(e.message)
    end
    # rubocop:enable Metrics/ParameterLists

    private_class_method def self.idempotent_check(trip, telegram_message_id)
      return if telegram_message_id.blank?

      existing = trip.journal_entries.find_by(telegram_message_id: telegram_message_id)
      tool_response(existing) if existing
    end

    private_class_method def self.create_entry(trip:, body:, **params)
      result = JournalEntries::Create.new.call(
        params: params.compact, trip: trip, user: resolve_jack_user
      )
      case result
      in Dry::Monads::Success(entry)
        entry.update!(body: body) if body.present?
        tool_response(entry)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = trip.journal_entries.find_by!(telegram_message_id: params[:telegram_message_id])
      tool_response(existing)
    end

    private_class_method def self.tool_response(entry)
      data = {
        id: entry.id, name: entry.name, entry_date: entry.entry_date.to_s,
        location_name: entry.location_name, actor_type: entry.actor_type,
        trip_id: entry.trip_id
      }
      MCP::Tool::Response.new([{ type: "text", text: data.to_json }])
    end

    private_class_method def self.error_response(errors)
      message = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.to_s
      MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
    end
  end
end
