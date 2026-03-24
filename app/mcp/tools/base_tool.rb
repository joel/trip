# frozen_string_literal: true

module Tools
  class BaseTool < MCP::Tool
    class ToolError < StandardError; end

    private_class_method def self.resolve_trip(trip_id)
      if trip_id.present?
        Trip.find(trip_id)
      else
        started = Trip.where(state: :started)
        case started.count
        when 1 then started.first
        when 0
          raise ToolError, "No active trip found. Provide an explicit trip_id."
        else
          ids = started.pluck(:id).join(", ")
          raise ToolError,
                "Multiple active trips: #{ids}. Provide an explicit trip_id."
        end
      end
    end

    private_class_method def self.resolve_jack_user
      User.find_or_create_by!(email: "jack@system.local") do |u|
        u.name = "Jack"
        u.status = 2
      end
    end
  end
end
