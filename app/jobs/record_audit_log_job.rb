# frozen_string_literal: true

# Persists one audit row off the request path and pushes it to the trip's
# Activity feed. Idempotent on retry via the unique event_uid. A logging
# failure must never surface to the user, so it degrades to a dropped row.
class RecordAuditLogJob < ApplicationJob
  queue_as :default

  def perform(attrs)
    log = AuditLog.create!(attrs)
    broadcast(log) if log.trip_id
  rescue ActiveRecord::RecordNotUnique
    # Already written by a previous attempt of this same logical event.
  end

  private

  def broadcast(log)
    html = ApplicationController.render(
      Components::AuditLogCard.new(audit_log: log), layout: false
    )
    ActionCable.server.broadcast(
      "audit_log:trip_#{log.trip_id}",
      { html: html, low_signal: log.low_signal? }
    )
  end
end
