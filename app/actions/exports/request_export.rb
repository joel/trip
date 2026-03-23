# frozen_string_literal: true

module Exports
  class RequestExport < BaseAction
    def call(trip:, user:, format:)
      yield check_no_active_export(trip, user, format)
      export = yield persist(trip, user, format)
      yield emit_event(export)
      Success(export)
    end

    private

    def check_no_active_export(trip, user, format)
      active = Export.exists?(trip: trip, user: user, format: format,
                              status: %i[pending processing])
      return Success() unless active

      errors = ActiveModel::Errors.new(Export.new)
      errors.add(:base, "An export is already in progress")
      Failure(errors)
    end

    def persist(trip, user, format)
      export = Export.create!(
        trip: trip, user: user, format: format
      )
      Success(export)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    rescue ArgumentError
      errors = ActiveModel::Errors.new(Export.new)
      errors.add(:format, :invalid)
      Failure(errors)
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
