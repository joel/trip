# frozen_string_literal: true

module Tools
  class UpdateChecklist < BaseTool
    description "Rename a checklist or change its sort position " \
                "(only on writable trips)"

    input_schema(
      properties: {
        checklist_id: {
          type: "string", description: "Checklist UUID"
        },
        name: { type: "string", description: "New checklist name" },
        position: {
          type: "integer", description: "New sort position"
        }
      },
      required: %w[checklist_id]
    )

    def self.call(checklist_id:, name: nil, position: nil,
                  _server_context: {})
      checklist = Checklist.find(checklist_id)
      require_writable!(checklist.trip)

      params = { name: name, position: position }.compact
      raise ToolError, "No updatable parameters provided" if params.empty?

      result = Checklists::Update.new.call(
        checklist: checklist, params: params
      )

      case result
      in Dry::Monads::Success(updated)
        success_response(
          id: updated.id, name: updated.name,
          position: updated.position
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Checklist not found: #{checklist_id}")
    end
  end
end
