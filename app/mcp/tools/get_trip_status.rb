# frozen_string_literal: true

module Tools
  class GetTripStatus < BaseTool
    description "Get the current status, dates, member count, " \
                "and entry count for a trip"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        }
      }
    )

    def self.call(trip_id: nil, _server_context: {})
      trip = resolve_trip(trip_id)

      success_response(
        id: trip.id, name: trip.name,
        state: trip.state, description: trip.description,
        start_date: trip.effective_start_date&.to_s,
        end_date: trip.effective_end_date&.to_s,
        member_count: trip.trip_memberships.count,
        entry_count: trip.journal_entries.count,
        checklist_count: trip.checklists.count
      )
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
