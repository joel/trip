# frozen_string_literal: true

module Tools
  class BaseTool < MCP::Tool
    class ToolError < StandardError; end

    VALID_ACTOR_TYPES = %w[Jack System].freeze

    # -- Shared response helpers --

    private_class_method def self.success_response(data)
      MCP::Tool::Response.new(
        [{ type: "text", text: data.to_json }]
      )
    end

    private_class_method def self.error_response(errors)
      message = if errors.respond_to?(:full_messages)
                  errors.full_messages.join(", ")
                else
                  errors.to_s
                end
      MCP::Tool::Response.new(
        [{ type: "text", text: message }], error: true
      )
    end

    # -- Trip resolution --

    private_class_method def self.resolve_trip(trip_id)
      if trip_id.present?
        Trip.find(trip_id)
      else
        started = Trip.where(state: :started).to_a
        case started.size
        when 1 then started.first
        when 0
          raise ToolError,
                "No active trip found. Provide an explicit trip_id."
        else
          ids = started.map(&:id).join(", ")
          raise ToolError,
                "Multiple active trips: #{ids}. " \
                "Provide an explicit trip_id."
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise ToolError, "Trip not found: #{trip_id}"
    end

    private_class_method def self.resolve_jack_user
      User.find_or_create_by!(email: "jack@system.local") do |u|
        u.name = "Jack"
        u.status = 2
      end
    end

    # -- Guards --

    private_class_method def self.require_writable!(trip)
      return if trip.writable?

      raise ToolError,
            "Trip '#{trip.name}' is not writable " \
            "(state: #{trip.state})"
    end

    private_class_method def self.require_commentable!(trip)
      return if trip.commentable?

      raise ToolError,
            "Trip '#{trip.name}' is not commentable " \
            "(state: #{trip.state})"
    end

    private_class_method def self.validate_actor_type!(actor_type)
      return if VALID_ACTOR_TYPES.include?(actor_type)

      raise ToolError,
            "Invalid actor_type \"#{actor_type}\". " \
            "Must be one of: #{VALID_ACTOR_TYPES.join(", ")}"
    end
  end
end
