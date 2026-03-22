# frozen_string_literal: true

class ChecklistSubscriber
  def emit(event)
    case event[:name]
    when "checklist.created"
      Rails.logger.info(
        "Checklist created: #{event[:payload][:checklist_id]}"
      )
    when "checklist.updated"
      Rails.logger.info(
        "Checklist updated: #{event[:payload][:checklist_id]}"
      )
    when "checklist.deleted"
      Rails.logger.info(
        "Checklist deleted: #{event[:payload][:checklist_id]}"
      )
    when "checklist_item.toggled"
      Rails.logger.info(
        "Checklist item toggled: " \
        "#{event[:payload][:checklist_item_id]}"
      )
    when "checklist_item.created"
      Rails.logger.info(
        "Checklist item created: " \
        "#{event[:payload][:checklist_item_id]}"
      )
    end
  end
end
