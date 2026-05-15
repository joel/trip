# frozen_string_literal: true

# Persists every domain event as an audit row. Runs synchronously in the
# request thread (so Current.* is populated for actor attribution) but
# only does O(1) work: build the attribute hash, then enqueue the write.
# A broken audit log must never break the user's action, so every failure
# is swallowed and logged.
class AuditLogSubscriber
  def emit(event)
    attrs = AuditLog::Builder.new(event).call
    RecordAuditLogJob.perform_later(attrs) if attrs
  rescue StandardError => e
    Rails.logger.error(
      "[audit] #{event[:name]} dropped: #{e.class}: #{e.message}"
    )
  end
end
