# frozen_string_literal: true

class McpController < ActionController::API
  before_action :authenticate_api_key!
  before_action :validate_content_type!

  def handle
    body = request.body.read
    JSON.parse(body) # Validate JSON before passing to MCP
    server = TripJournalServer.build(
      server_context: { request_id: request.uuid }
    )
    render json: server.handle_json(body)
  rescue JSON::ParserError
    render json: {
      jsonrpc: "2.0", id: nil,
      error: { code: -32_700, message: "Parse error" }
    }, status: :ok
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
end
