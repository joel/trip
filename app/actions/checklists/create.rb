# frozen_string_literal: true

module Checklists
  class Create < BaseAction
    def call(params:, trip:)
      checklist = yield persist(params, trip)
      yield emit_event(checklist)
      Success(checklist)
    end

    private

    def persist(params, trip)
      checklist = trip.checklists.create!(params)
      Success(checklist)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(checklist)
      Rails.event.notify(
        "checklist.created",
        checklist_id: checklist.id, trip_id: checklist.trip_id
      )
      Success()
    end
  end
end
