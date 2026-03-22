# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trips" do
  let(:admin) { create(:user, :superadmin) }

  before { login_as(user: admin) }

  it "lists trips" do
    create(:trip, name: "Test Trip", created_by: admin)
    create(:trip_membership, trip: Trip.last, user: admin)
    visit trips_path
    expect(page).to have_content("Test Trip")
  end

  it "shows empty state" do
    visit trips_path
    expect(page).to have_content("No trips yet")
  end

  it "creates a new trip" do
    visit new_trip_path
    fill_in "Name", with: "New Trip"
    click_on "Create Trip"
    expect(page).to have_content("Trip created")
    expect(page).to have_content("New Trip")
  end

  it "shows trip details" do
    trip = create(:trip, name: "Detail Trip", created_by: admin)
    visit trip_path(trip)
    expect(page).to have_content("Detail Trip")
    expect(page).to have_content("Planning")
  end

  it "edits a trip" do
    trip = create(:trip, name: "Old Name", created_by: admin)
    visit edit_trip_path(trip)
    fill_in "Name", with: "New Name"
    click_on "Update Trip"
    expect(page).to have_content("Trip updated")
    expect(page).to have_content("New Name")
  end
end
