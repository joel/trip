# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Journal Entries" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  it "creates a journal entry" do
    visit new_trip_journal_entry_path(trip)
    fill_in "Name", with: "Day One"
    fill_in "Entry date", with: Date.current.to_s
    click_on "Create Journal entry"
    expect(page).to have_content("Entry created")
    expect(page).to have_content("Day One")
  end

  it "shows a journal entry" do
    entry = create(:journal_entry, trip: trip, author: admin,
                                   name: "My Entry")
    visit trip_journal_entry_path(trip, entry)
    expect(page).to have_content("My Entry")
  end
end
