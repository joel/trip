# frozen_string_literal: true

module ChecklistItems
  class Create < BaseAction
    def call(params:, checklist_section:)
      item = yield persist(params, checklist_section)
      yield emit_event(item)
      Success(item)
    end

    private

    def persist(params, checklist_section)
      item = checklist_section.checklist_items.create!(params)
      Success(item)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(item)
      Rails.event.notify(
        "checklist_item.created",
        checklist_item_id: item.id,
        checklist_id: item.checklist_section.checklist_id
      )
      Success()
    end
  end
end
