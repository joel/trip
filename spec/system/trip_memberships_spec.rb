# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trip Memberships" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: admin)
    login_as(user: admin)
  end

  it "lists trip members" do
    visit trip_trip_memberships_path(trip)
    expect(page).to have_text("Trip Members")
    expect(page).to have_text(admin.email)
  end

  it "adds a member to a trip" do
    new_member = create(:user, name: "New Member")
    visit new_trip_trip_membership_path(trip)
    select new_member.email, from: "User"
    click_on "Add member"
    expect(page).to have_text("Member added")
  end

  it "removes a member from a trip" do
    member = create(:user, name: "Removable")
    create(:trip_membership, trip: trip, user: member)
    visit trip_trip_memberships_path(trip)
    expect(page).to have_text(member.email)
    click_on "Remove", match: :first
    expect(page).to have_text("Member removed")
  end
end
