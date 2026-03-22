# frozen_string_literal: true

module ChecklistItems
  class Toggle < BaseAction
    def call(checklist_item:)
      yield toggle(checklist_item)
      yield emit_event(checklist_item)
      Success(checklist_item)
    end

    private

    def toggle(checklist_item)
      checklist_item.toggle!
      Success()
    end

    def emit_event(checklist_item)
      section = checklist_item.checklist_section
      Rails.event.notify(
        "checklist_item.toggled",
        checklist_item_id: checklist_item.id,
        checklist_id: section.checklist_id
      )
      Success()
    end
  end
end
