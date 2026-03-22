# frozen_string_literal: true

module Checklists
  class Update < BaseAction
    def call(checklist:, params:)
      yield persist(checklist, params)
      yield emit_event(checklist)
      Success(checklist)
    end

    private

    def persist(checklist, params)
      checklist.update!(params)
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(checklist)
      Rails.event.notify(
        "checklist.updated",
        checklist_id: checklist.id, trip_id: checklist.trip_id
      )
      Success()
    end
  end
end
