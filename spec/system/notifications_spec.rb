# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  before { login_as(user: admin) }

  it "shows bell icon in sidebar" do
    visit root_path
    expect(page).to have_content("Notifications")
  end

  it "shows unread badge in mobile navigation" do
    actor = create(:user)
    create(:notification,
           recipient: admin,
           actor: actor,
           notifiable: entry,
           event_type: :entry_created)

    visit root_path
    mobile_nav = find(
      "nav[aria-label='Mobile navigation']", visible: :all
    )
    badge = mobile_nav.find(
      "[data-notification-badge-target='count']", visible: :all
    )
    expect(badge.text(:all)).to eq("1")
    expect(badge[:class]).not_to include("hidden")
  end

  it "hides badge in mobile navigation when no unread notifications" do
    visit root_path
    mobile_nav = find(
      "nav[aria-label='Mobile navigation']", visible: :all
    )
    badge = mobile_nav.find(
      "[data-notification-badge-target='count']", visible: :all
    )
    expect(badge[:class]).to include("hidden")
  end

  it "shows empty notifications page" do
    visit notifications_path
    expect(page).to have_content("No notifications yet")
  end

  it "shows notifications" do
    actor = create(:user)
    create(:notification,
           recipient: admin,
           actor: actor,
           notifiable: entry,
           event_type: :entry_created)

    visit notifications_path
    expect(page).to have_content("created a new journal entry")
  end

  it "marks a notification as read" do
    actor = create(:user)
    create(:notification,
           recipient: admin,
           actor: actor,
           notifiable: entry,
           event_type: :entry_created)

    visit notifications_path
    click_on "Mark read"
    expect(page).to have_content("Notification marked as read")
  end

  it "marks all notifications as read" do
    actor = create(:user)
    create(:notification,
           recipient: admin,
           actor: actor,
           notifiable: entry,
           event_type: :entry_created)

    visit notifications_path
    click_on "Mark all as read"
    expect(page).to have_content("All notifications marked as read")
  end

  it "shows mute toggle on trip feed" do
    create(:trip_membership, trip: trip, user: admin)
    create(:journal_entry_subscription,
           user: admin, journal_entry: entry)

    visit trip_path(trip)
    expect(page).to have_css(
      "[title='Notifications on — click to mute']"
    )
  end
end
