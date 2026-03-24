# frozen_string_literal: true

module Tools
  class UpdateTrip < BaseTool
    description "Update a trip's name or description"

    input_schema(
      properties: {
        trip_id: { type: "string", description: "Trip UUID (optional if exactly one trip is started)" },
        name: { type: "string", description: "New trip name" },
        description: { type: "string", description: "New trip description" }
      }
    )

    def self.call(trip_id: nil, name: nil, description: nil,
                  _server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)
      params = { name: name, description: description }.compact

      result = Trips::Update.new.call(trip: trip, params: params)

      case result
      in Dry::Monads::Success(updated)
        MCP::Tool::Response.new([{
                                  type: "text",
                                  text: { id: updated.id, name: updated.name,
                                          state: updated.state }.to_json
                                }])
      in Dry::Monads::Failure(errors)
        message = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.to_s
        MCP::Tool::Response.new(
          [{ type: "text", text: message }], error: true
        )
      end
    rescue ToolError => e
      MCP::Tool::Response.new(
        [{ type: "text", text: e.message }], error: true
      )
    end
  end
end
