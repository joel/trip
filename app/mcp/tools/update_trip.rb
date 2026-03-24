# frozen_string_literal: true

module Tools
  class UpdateTrip < BaseTool
    description "Update a trip's name or description"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        },
        name: { type: "string", description: "New trip name" },
        description: {
          type: "string", description: "New trip description"
        }
      }
    )

    def self.call(trip_id: nil, name: nil, description: nil,
                  _server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)
      params = { name: name, description: description }.compact
      raise ToolError, "No updatable parameters provided" if params.empty?

      result = Trips::Update.new.call(trip: trip, params: params)

      case result
      in Dry::Monads::Success(updated)
        success_response(
          id: updated.id, name: updated.name,
          state: updated.state
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
