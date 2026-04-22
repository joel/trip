# frozen_string_literal: true

class McpController < ActionController::API
  before_action :authenticate_api_key!
  before_action :validate_content_type!

  def handle
    body = request.body.read
    JSON.parse(body) # Validate JSON before passing to MCP

    return render_agent_error(:missing) if agent_slug.blank?

    agent = Agent.by_slug(agent_slug)
    return render_agent_error(:unknown, agent_slug) if agent.nil?

    server = TripJournalServer.build(
      server_context: { request_id: request.uuid, agent: agent }
    )
    render json: server.handle_json(body)
  rescue JSON::ParserError
    render json: parse_error_payload, status: :ok
  end

  private

  def authenticate_api_key!
    expected = ENV.fetch("MCP_API_KEY", nil)
    return head(:unauthorized) if expected.blank?

    provided = request.headers["Authorization"]&.delete_prefix("Bearer ")
    head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(
      provided.to_s, expected
    )
  end

  def validate_content_type!
    content_type = request.content_type.to_s
    return if content_type.start_with?("application/json")

    head(:unsupported_media_type)
  end

  def agent_slug
    @agent_slug ||= request.headers["X-Agent-Identifier"].to_s.strip
  end

  def render_agent_error(kind, slug = nil)
    message =
      case kind
      when :missing
        "Missing X-Agent-Identifier header. Configure your MCP " \
        "client with the slug of your registered agent " \
        "(e.g. 'jack')."
      when :unknown
        "Agent '#{slug}' is not registered. Ask the admin to " \
        "create an Agent record with this slug."
      end
    render json: {
      jsonrpc: "2.0", id: nil,
      error: { code: -32_001, message: message }
    }, status: :ok
  end

  def parse_error_payload
    { jsonrpc: "2.0", id: nil,
      error: { code: -32_700, message: "Parse error" } }
  end
end
