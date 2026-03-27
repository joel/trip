# frozen_string_literal: true

class CreateNotificationJob < ApplicationJob
  queue_as :default

  def perform(notifiable_type:, notifiable_id:, recipient_id:,
              actor_id:, event_type:)
    Notification.create!(
      notifiable_type: notifiable_type,
      notifiable_id: notifiable_id,
      recipient_id: recipient_id,
      actor_id: actor_id,
      event_type: event_type
    )
    broadcast_unread_count(recipient_id)
  rescue ActiveRecord::RecordNotUnique
    # Idempotent: notification already exists (job retry safety)
  end

  private

  def broadcast_unread_count(user_id)
    count = Notification.where(recipient_id: user_id).unread.count
    ActionCable.server.broadcast(
      "notifications:user_#{user_id}",
      { unread_count: count }
    )
  end
end
