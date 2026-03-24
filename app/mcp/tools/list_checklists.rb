# frozen_string_literal: true

module Tools
  class ListChecklists < BaseTool
    description "List all checklists with sections and items " \
                "for a trip"

    input_schema(
      properties: {
        trip_id: {
          type: "string",
          description: "Trip UUID (optional if exactly one " \
                       "trip is started)"
        }
      }
    )

    def self.call(trip_id: nil, _server_context: {})
      trip = resolve_trip(trip_id)

      checklists = trip.checklists.ordered.includes(
        checklist_sections: :checklist_items
      ).map do |cl|
        {
          id: cl.id, name: cl.name,
          sections: cl.checklist_sections.map do |sec|
            {
              id: sec.id, name: sec.name,
              items: sec.checklist_items.map do |item|
                { id: item.id, content: item.content,
                  completed: item.completed }
              end
            }
          end
        }
      end

      success_response(checklists: checklists)
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
