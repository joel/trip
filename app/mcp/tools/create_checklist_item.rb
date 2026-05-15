# frozen_string_literal: true

module Tools
  class CreateChecklistItem < BaseTool
    description "Add a new item to an existing checklist section " \
                "(only on writable trips)"

    input_schema(
      properties: {
        checklist_section_id: {
          type: "string", description: "Checklist section UUID"
        },
        content: {
          type: "string", description: "Item text"
        },
        position: {
          type: "integer", description: "Sort position (optional)"
        }
      },
      required: %w[checklist_section_id content]
    )

    def self.call(checklist_section_id:, content:, position: nil,
                  _server_context: {})
      section = ChecklistSection.find(checklist_section_id)
      require_writable!(section.checklist.trip)

      params = { content: content, position: position }.compact
      result = ChecklistItems::Create.new.call(
        params: params, checklist_section: section
      )

      case result
      in Dry::Monads::Success(item)
        success_response(
          id: item.id, content: item.content,
          completed: item.completed,
          checklist_section_id: section.id
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response(
        "Checklist section not found: #{checklist_section_id}"
      )
    end
  end
end
