# frozen_string_literal: true

module Tools
  class ListTrips < BaseTool
    description "List all trips (any state, including archived) " \
                "with pagination"

    input_schema(
      properties: {
        limit: {
          type: "integer",
          description: "Max trips to return (default 10, max 100)"
        },
        offset: {
          type: "integer",
          description: "Number of trips to skip (default 0)"
        }
      }
    )

    def self.call(limit: 10, offset: 0, _server_context: {})
      limit = limit.to_i.clamp(1, 100)
      offset = [offset.to_i, 0].max

      trips = Trip.order(created_at: :desc).offset(offset).limit(limit).to_a
      ids = trips.map(&:id)
      members = TripMembership.where(trip_id: ids).group(:trip_id).count
      entries = JournalEntry.where(trip_id: ids).group(:trip_id).count

      success_response(
        trips: trips.map { |trip| serialize(trip, members, entries) },
        total: Trip.count, limit: limit, offset: offset
      )
    end

    private_class_method def self.serialize(trip, members, entries)
      {
        id: trip.id, name: trip.name, state: trip.state,
        start_date: trip.start_date&.to_s,
        end_date: trip.end_date&.to_s,
        member_count: members.fetch(trip.id, 0),
        entry_count: entries.fetch(trip.id, 0)
      }
    end
  end
end
