# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Checklists" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, :started, created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: admin,
                             role: :contributor)
    login_as(user: admin)
  end

  it "shows empty checklists index" do
    visit trip_checklists_path(trip)
    expect(page).to have_text("Checklists")
    expect(page).to have_text("No checklists yet")
  end

  it "creates a checklist" do
    visit new_trip_checklist_path(trip)
    fill_in "Name", with: "Packing List"
    click_on "Create Checklist"
    expect(page).to have_text("Checklist created")
    expect(page).to have_text("Packing List")
  end

  it "shows a checklist" do
    checklist = create(:checklist, trip: trip, name: "Gear")
    visit trip_checklist_path(trip, checklist)
    expect(page).to have_text("Gear")
  end

  it "edits a checklist" do
    checklist = create(:checklist, trip: trip, name: "Old Name")
    visit edit_trip_checklist_path(trip, checklist)
    fill_in "Name", with: "Updated Name"
    click_on "Update Checklist"
    expect(page).to have_text("Checklist updated")
    expect(page).to have_text("Updated Name")
  end

  it "deletes a checklist" do
    checklist = create(:checklist, trip: trip, name: "Temp List")
    visit trip_checklist_path(trip, checklist)
    click_on "Delete"
    expect(page).to have_text("Checklist deleted")
  end

  it "adds a section to a checklist" do
    checklist = create(:checklist, trip: trip)
    visit trip_checklist_path(trip, checklist)
    fill_in "checklist_section[name]", with: "Clothing"
    click_on "Add section"
    expect(page).to have_text("Clothing")
  end

  it "adds an item to a section" do
    checklist = create(:checklist, trip: trip)
    create(:checklist_section, checklist: checklist,
                               name: "Essentials")
    visit trip_checklist_path(trip, checklist)
    fill_in "checklist_item[content]", with: "Passport"
    click_on "Add"
    expect(page).to have_text("Passport")
  end

  it "removes a checklist item" do
    checklist = create(:checklist, trip: trip)
    section = create(:checklist_section, checklist: checklist)
    create(:checklist_item, checklist_section: section,
                            content: "Sunglasses")
    visit trip_checklist_path(trip, checklist)
    expect(page).to have_text("Sunglasses")
    click_on "Remove"
    expect(page).to have_text("Item removed")
  end
end
