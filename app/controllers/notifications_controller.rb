# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_notification, only: [:mark_as_read]

  def index
    authorize!(Notification)
    @notifications = current_user.notifications.recent
                                 .includes(:actor)
    render Views::Notifications::Index.new(
      notifications: @notifications
    )
  end

  def mark_as_read
    authorize!(@notification)
    @notification.mark_as_read!
    redirect_to notifications_path,
                notice: "Notification marked as read."
  end

  def mark_all_as_read
    authorize!(Notification)
    current_user.notifications.unread
                .update_all(read_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    redirect_to notifications_path,
                notice: "All notifications marked as read."
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
