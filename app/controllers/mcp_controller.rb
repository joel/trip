# frozen_string_literal: true

class McpController < ActionController::API
  before_action :authenticate_api_key!

  def handle
    server = TripJournalServer.build(
      server_context: { request_id: request.uuid }
    )
    render json: server.handle_json(request.body.read)
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
end
