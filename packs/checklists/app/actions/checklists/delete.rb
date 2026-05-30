# frozen_string_literal: true

module Checklists
  class Delete < BaseAction
    def call(checklist:)
      checklist_id = checklist.id
      trip_id = checklist.trip_id
      yield destroy(checklist)
      yield emit_event(checklist_id, trip_id)
      Success()
    end

    private

    def destroy(checklist)
      checklist.destroy!
      Success()
    end

    def emit_event(checklist_id, trip_id)
      Rails.event.notify(
        "checklist.deleted",
        checklist_id: checklist_id, trip_id: trip_id
      )
      Success()
    end
  end
end
