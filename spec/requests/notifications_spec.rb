# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "GET /notifications" do
    before { stub_current_user(admin) }

    it "returns success" do
      get notifications_path
      expect(response).to be_successful
    end

    it "lists notifications for the current user" do
      create(:notification, recipient: admin, notifiable: entry)
      get notifications_path
      expect(response).to be_successful
    end
  end

  describe "PATCH /notifications/:id/mark_as_read" do
    before { stub_current_user(admin) }

    it "marks a notification as read" do
      notification = create(:notification, recipient: admin,
                                           notifiable: entry)
      patch mark_as_read_notification_path(notification)

      expect(notification.reload.read_at).to be_present
      expect(response).to redirect_to(notifications_path)
    end
  end

  describe "PATCH /notifications/mark_all_as_read" do
    before { stub_current_user(admin) }

    it "marks all unread notifications as read" do
      create(:notification, recipient: admin, notifiable: entry)
      other_entry = create(:journal_entry, trip: trip,
                                           author: admin)
      create(:notification, recipient: admin,
                            notifiable: other_entry)

      patch mark_all_as_read_notifications_path

      expect(
        admin.notifications.unread.count
      ).to eq(0)
      expect(response).to redirect_to(notifications_path)
    end
  end

  describe "unauthenticated access" do
    before { stub_current_user(nil) }

    it "returns unauthorized for index" do
      get notifications_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
