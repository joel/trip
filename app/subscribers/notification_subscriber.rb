# frozen_string_literal: true

class NotificationSubscriber
  def emit(event)
    case event[:name]
    when "journal_entry.created"
      NotifyEntryCreatedJob.perform_later(
        event[:payload][:journal_entry_id],
        event[:payload][:actor_id]
      )
    when "comment.created"
      NotifyCommentAddedJob.perform_later(
        event[:payload][:comment_id],
        event[:payload][:actor_id]
      )
    end
  end
end
