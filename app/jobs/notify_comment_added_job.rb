# frozen_string_literal: true

class NotifyCommentAddedJob < ApplicationJob
  queue_as :default

  def perform(comment_id, actor_id)
    comment = Comment.find_by(id: comment_id)
    return unless comment

    entry = comment.journal_entry
    entry.subscribers.where.not(id: actor_id).find_each do |sub|
      CreateNotificationJob.perform_later(
        notifiable_type: "Comment",
        notifiable_id: comment.id,
        recipient_id: sub.id,
        actor_id: actor_id,
        event_type: "comment_added"
      )
      NotificationMailer.comment_added(
        comment.id, sub.id
      ).deliver_later
    end
  end
end
