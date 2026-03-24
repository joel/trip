# frozen_string_literal: true

module Tools
  class ListJournalEntries < BaseTool
    description "List journal entries for a trip with pagination"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        },
        limit: {
          type: "integer",
          description: "Max entries to return (default 10, " \
                       "max 100)"
        },
        offset: {
          type: "integer",
          description: "Number of entries to skip (default 0)"
        }
      }
    )

    def self.call(trip_id: nil, limit: 10, offset: 0,
                  _server_context: {})
      trip = resolve_trip(trip_id)
      limit = limit.to_i.clamp(1, 100)
      offset = [offset.to_i, 0].max

      entries = trip.journal_entries
                    .chronological
                    .offset(offset)
                    .limit(limit)
                    .map do |e|
        {
          id: e.id, name: e.name,
          entry_date: e.entry_date.to_s,
          location_name: e.location_name,
          description: e.description,
          actor_type: e.actor_type,
          comments_count: e.comments.size
        }
      end

      success_response(
        entries: entries,
        total: trip.journal_entries.count,
        limit: limit, offset: offset
      )
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
