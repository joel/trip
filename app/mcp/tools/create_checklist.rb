# frozen_string_literal: true

module Tools
  class CreateChecklist < BaseTool
    description "Create a new checklist on a trip"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        },
        name: { type: "string", description: "Checklist name" },
        position: {
          type: "integer",
          description: "Sort position (optional)"
        }
      },
      required: %w[name]
    )

    def self.call(name:, trip_id: nil, position: nil,
                  _server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)

      params = { name: name, position: position }.compact
      result = Checklists::Create.new.call(params: params, trip: trip)

      case result
      in Dry::Monads::Success(checklist)
        success_response(
          id: checklist.id, name: checklist.name,
          trip_id: checklist.trip_id, position: checklist.position
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
