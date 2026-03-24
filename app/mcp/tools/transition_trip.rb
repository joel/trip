# frozen_string_literal: true

module Tools
  class TransitionTrip < BaseTool
    description "Transition a trip to a new state (start, finish, cancel)"

    input_schema(
      properties: {
        trip_id: { type: "string", description: "Trip UUID (optional if exactly one trip is started)" },
        new_state: { type: "string", description: "Target state: started, finished, cancelled, archived, planning" }
      },
      required: %w[new_state]
    )

    def self.call(new_state:, trip_id: nil, _server_context: {})
      trip = resolve_trip(trip_id)

      result = Trips::TransitionState.new.call(
        trip: trip, new_state: new_state
      )

      case result
      in Dry::Monads::Success(updated)
        MCP::Tool::Response.new([{
                                  type: "text",
                                  text: { id: updated.id, name: updated.name,
                                          state: updated.state }.to_json
                                }])
      in Dry::Monads::Failure(error)
        MCP::Tool::Response.new(
          [{ type: "text", text: error.to_s }], error: true
        )
      end
    rescue ToolError => e
      MCP::Tool::Response.new(
        [{ type: "text", text: e.message }], error: true
      )
    end
  end
end
