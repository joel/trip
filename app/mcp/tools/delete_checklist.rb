# frozen_string_literal: true

module Tools
  class DeleteChecklist < BaseTool
    description "Delete a checklist and its sections/items " \
                "(only on writable trips)"

    input_schema(
      properties: {
        checklist_id: {
          type: "string", description: "Checklist UUID"
        }
      },
      required: %w[checklist_id]
    )

    def self.call(checklist_id:, _server_context: {})
      checklist = Checklist.find(checklist_id)
      require_writable!(checklist.trip)

      result = Checklists::Delete.new.call(checklist: checklist)

      case result
      in Dry::Monads::Success()
        success_response(deleted: true, id: checklist_id)
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
