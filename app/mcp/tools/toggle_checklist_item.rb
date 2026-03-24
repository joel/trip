# frozen_string_literal: true

module Tools
  class ToggleChecklistItem < BaseTool
    description "Toggle a checklist item's completion status"

    input_schema(
      properties: {
        checklist_item_id: { type: "string", description: "Checklist item UUID" }
      },
      required: %w[checklist_item_id]
    )

    def self.call(checklist_item_id:, _server_context: {})
      item = ChecklistItem.find(checklist_item_id)
      require_writable!(item.checklist_section.checklist.trip)

      result = ChecklistItems::Toggle.new.call(checklist_item: item)

      case result
      in Dry::Monads::Success(toggled)
        MCP::Tool::Response.new([{
                                  type: "text",
                                  text: { id: toggled.id, content: toggled.content,
                                          completed: toggled.completed }.to_json
                                }])
      in Dry::Monads::Failure(errors)
        MCP::Tool::Response.new(
          [{ type: "text", text: errors.to_s }], error: true
        )
      end
    rescue ToolError => e
      MCP::Tool::Response.new(
        [{ type: "text", text: e.message }], error: true
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [{ type: "text", text: "Checklist item not found: #{checklist_item_id}" }],
        error: true
      )
    end
  end
end
