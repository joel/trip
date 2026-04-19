# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trip viewer visibility" do
  let(:owner) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user, name: "Carla Contributor") }
  let(:viewer_user) { create(:user, name: "Vera Viewer") }
  let(:trip) { create(:trip, name: "Family Trip", created_by: owner) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  context "when logged in as a viewer" do
    before { login_as(user: viewer_user) }

    it "hides Members, Checklists, and Exports buttons on trip show" do
      visit trip_path(trip)
      expect(page).to have_content("Family Trip")
      expect(page).to have_no_link("Members")
      expect(page).to have_no_link("Checklists")
      expect(page).to have_no_link("Exports")
    end

    it "denies direct access to /trip_memberships" do
      visit trip_trip_memberships_path(trip)
      expect(page).to have_content("Access denied")
    end

    it "denies direct access to /checklists" do
      visit trip_checklists_path(trip)
      expect(page).to have_content("Access denied")
    end

    it "denies direct access to /exports" do
      visit trip_exports_path(trip)
      expect(page).to have_content("Access denied")
    end
  end

  context "when logged in as a contributor" do
    before { login_as(user: contributor_user) }

    it "shows Members, Checklists, and Exports buttons on trip show" do
      visit trip_path(trip)
      expect(page).to have_content("Family Trip")
      expect(page).to have_link("Members")
      expect(page).to have_link("Checklists")
      expect(page).to have_link("Exports")
    end
  end
end
