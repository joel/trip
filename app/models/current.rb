# frozen_string_literal: true

# Request-scoped actor context. Set once per request in ApplicationController
# (web) and McpController (agents), read synchronously by AuditLogSubscriber
# (Rails.event dispatches subscribers inline in the request thread — verified
# Phase 21 Task 0), then passed to RecordAuditLogJob as plain arguments.
class Current < ActiveSupport::CurrentAttributes
  attribute :actor      # User performing the action, or nil for system
  attribute :request_id # request.request_id, used to correlate a burst
  attribute :source     # :web | :mcp | :telegram | :system (defaults :web)
end
