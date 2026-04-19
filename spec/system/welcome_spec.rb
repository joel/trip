# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Welcome" do
  it "renders the home page for visitors" do
    visit root_path
    expect(page).to have_content("Welcome to Catalyst")
    expect(page).to have_content("Request an invitation")
    expect(page).to have_link("Request Access")
    expect(page).to have_no_content("Returning?")
  end

  context "when logged in" do
    let(:admin) { create(:user, :superadmin, name: "Joel Azemar") }

    before { login_as(user: admin) }

    context "with no trips" do
      it "renders the empty-state hero" do
        visit root_path
        expect(page).to have_content(/Welcome,/)
        expect(page).to have_content(
          "No trips yet! Don't worry, a new one will be added in no time."
        )
      end

      it "shows a New Trip CTA for admins" do
        visit root_path
        expect(page).to have_link("New Trip")
      end

      it "does not render the Add a passkey security panel" do
        visit root_path
        expect(page).to have_content(/Welcome,/)
        expect(page).to have_no_content("Add a passkey")
        expect(page).to have_no_content("Register a passkey per device")
      end
    end

    context "with one trip" do
      it "redirects to that trip" do
        trip = create(:trip, name: "Solo Trip", created_by: admin)
        create(:trip_membership, trip: trip, user: admin)
        visit root_path
        expect(page).to have_current_path(trip_path(trip))
      end
    end

    context "with two or more trips and one started" do
      it "redirects to the started trip" do
        planning = create(:trip, name: "Planning Trip", created_by: admin)
        create(:trip_membership, trip: planning, user: admin)
        started = create(:trip, :started, name: "Started Trip",
                                          created_by: admin)
        create(:trip_membership, trip: started, user: admin)
        visit root_path
        expect(page).to have_current_path(trip_path(started))
      end
    end

    context "with two or more trips and none started" do
      it "redirects to /trips" do
        a = create(:trip, name: "Trip A", created_by: admin)
        create(:trip_membership, trip: a, user: admin)
        b = create(:trip, name: "Trip B", created_by: admin)
        create(:trip_membership, trip: b, user: admin)
        visit root_path
        expect(page).to have_current_path(trips_path)
      end
    end
  end
end
