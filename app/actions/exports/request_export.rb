# frozen_string_literal: true

module Exports
  class RequestExport < BaseAction
    def call(trip:, user:, format:)
      export = yield persist(trip, user, format)
      yield emit_event(export)
      Success(export)
    end

    private

    def persist(trip, user, format)
      export = Export.create!(
        trip: trip, user: user, format: format
      )
      Success(export)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(export)
      Rails.event.notify(
        "export.requested",
        export_id: export.id,
        trip_id: export.trip_id,
        user_id: export.user_id,
        format: export.format
      )
      Success()
    end
  end
end
