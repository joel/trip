# frozen_string_literal: true

module Tools
  class ListJournalEntries < BaseTool
    description "List journal entries for a trip with pagination"

    input_schema(
      properties: {
        trip_id: { type: "string", description: "Trip UUID (optional if exactly one trip is started)" },
        limit: { type: "integer", description: "Max entries to return (default 10)" },
        offset: { type: "integer", description: "Number of entries to skip (default 0)" }
      }
    )

    def self.call(trip_id: nil, limit: 10, offset: 0, _server_context: {})
      trip = resolve_trip(trip_id)

      entries = trip.journal_entries
                    .chronological
                    .includes(:comments)
                    .offset(offset)
                    .limit(limit)
                    .map do |e|
        {
          id: e.id, name: e.name, entry_date: e.entry_date.to_s,
          location_name: e.location_name, description: e.description,
          actor_type: e.actor_type, comments_count: e.comments.size
        }
      end

      MCP::Tool::Response.new([{
                                type: "text",
                                text: { entries: entries, total: trip.journal_entries.count,
                                        limit: limit, offset: offset }.to_json
                              }])
    rescue ToolError => e
      MCP::Tool::Response.new(
        [{ type: "text", text: e.message }], error: true
      )
    end
  end
end
