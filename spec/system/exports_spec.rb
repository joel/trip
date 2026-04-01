# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Exports" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, :started, created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: admin)
    login_as(user: admin)
  end

  it "shows empty exports index" do
    visit trip_exports_path(trip)
    expect(page).to have_content("Exports")
    expect(page).to have_content("No exports yet")
  end

  it "requests a new export" do
    visit new_trip_export_path(trip)
    expect(page).to have_content("New Export")
    click_on "Request Export"
    expect(page).to have_content("Export requested")
  end
end
