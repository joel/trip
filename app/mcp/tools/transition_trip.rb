# frozen_string_literal: true

module Tools
  class TransitionTrip < BaseTool
    VALID_STATES = %w[
      planning started finished cancelled archived
    ].freeze

    description(
      "Transition a trip to a new state. Valid transitions: " \
      "planning -> started/cancelled, " \
      "started -> finished/cancelled, " \
      "finished -> archived, " \
      "cancelled -> planning"
    )

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        },
        new_state: {
          type: "string",
          description: "Target state",
          enum: VALID_STATES
        }
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
        success_response(
          id: updated.id, name: updated.name,
          state: updated.state
        )
      in Dry::Monads::Failure(error)
        error_response(error)
      end
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
