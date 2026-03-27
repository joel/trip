# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_notification, only: [:mark_as_read]

  def index
    authorize!(Notification)
    @notifications = current_user.notifications.recent
                                 .includes(:actor, :notifiable)
                                 .limit(50)
    preload_notifiable_associations(@notifications)
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

  def preload_notifiable_associations(notifications)
    grouped = notifications.group_by(&:notifiable_type)
    preload_type(grouped, "TripMembership", :trip)
    preload_type(grouped, "JournalEntry", :trip)
    preload_type(grouped, "Comment", { journal_entry: :trip })
  end

  def preload_type(grouped, type, assoc)
    records = grouped[type]&.filter_map(&:notifiable)
    return if records.blank?

    ActiveRecord::Associations::Preloader.new(
      records: records,
      associations: Array.wrap(assoc)
    ).call
  end
end
