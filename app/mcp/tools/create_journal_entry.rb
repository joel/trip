# frozen_string_literal: true

module Tools
  class CreateJournalEntry < BaseTool
    description "Create a journal entry for a trip"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        },
        name: { type: "string", description: "Entry title" },
        body: {
          type: "string",
          description: "Entry body (rich text)"
        },
        entry_date: {
          type: "string",
          description: "Date in YYYY-MM-DD format"
        },
        location_name: {
          type: "string",
          description: "Human-readable location"
        },
        description: {
          type: "string", description: "Short summary"
        },
        telegram_message_id: {
          type: "string",
          description: "Telegram message ID for idempotency"
        }
      },
      required: %w[name entry_date]
    )

    # rubocop:disable Metrics/ParameterLists
    def self.call(name:, entry_date:, trip_id: nil, body: nil,
                  location_name: nil, description: nil,
                  telegram_message_id: nil, server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)
      user = resolve_agent_user(server_context)
      idempotent_check(trip, telegram_message_id) || create_entry(
        trip: trip, name: name, entry_date: entry_date, body: body,
        location_name: location_name, description: description,
        telegram_message_id: telegram_message_id, user: user
      )
    rescue ToolError => e
      error_response(e.message)
    end
    # rubocop:enable Metrics/ParameterLists

    private_class_method def self.idempotent_check(trip, msg_id)
      return if msg_id.blank?

      existing = trip.journal_entries.find_by(
        telegram_message_id: msg_id
      )
      entry_response(existing) if existing
    end

    private_class_method def self.create_entry(trip:, body:, user:, **params)
      result = JournalEntries::Create.new.call(
        params: params.compact, trip: trip, user: user
      )
      case result
      in Dry::Monads::Success(entry)
        entry.update!(body: body) if body.present?
        entry_response(entry)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = trip.journal_entries.find_by!(
        telegram_message_id: params[:telegram_message_id]
      )
      entry_response(existing)
    end

    private_class_method def self.entry_response(entry)
      success_response(
        id: entry.id, name: entry.name,
        entry_date: entry.entry_date.to_s,
        location_name: entry.location_name,
        trip_id: entry.trip_id
      )
    end
  end
end
