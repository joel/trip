# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Journal Entries Feed Wall" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  it "creates a journal entry and shows it on the trip page" do
    visit new_trip_journal_entry_path(trip)
    fill_in "Name", with: "Day One"
    fill_in "Entry date", with: Date.current.to_s
    click_on "Create Journal entry"
    expect(page).to have_text("Entry created")
    expect(page).to have_text("Day One")
    expect(page).to have_current_path(
      trip_path(trip), ignore_query: true
    )
  end

  it "displays entries newest first on the trip page" do
    create(:journal_entry, trip: trip, author: admin,
                           name: "Older Entry",
                           entry_date: Date.new(2026, 3, 1))
    create(:journal_entry, trip: trip, author: admin,
                           name: "Newer Entry",
                           entry_date: Date.new(2026, 3, 5))

    visit trip_path(trip)
    entries = page.all("article")
    names = entries.map(&:text)
    newer_idx = names.index { |t| t.include?("Newer Entry") }
    older_idx = names.index { |t| t.include?("Older Entry") }
    expect(newer_idx).to be < older_idx
  end

  it "expands a card in place without navigation", :js do
    create(:journal_entry, trip: trip, author: admin,
                           name: "Expandable Entry",
                           description: "Short preview")

    visit trip_path(trip)
    expect(page).to have_text("Expandable Entry")
    click_on "Read more"
    expect(page).to have_text("Collapse")
    expect(page).to have_current_path(
      trip_path(trip), ignore_query: true
    )
  end

  it "edits a journal entry from the feed" do
    entry = create(:journal_entry, trip: trip, author: admin,
                                   name: "Old Title")
    visit trip_path(trip)
    within "#journal_entry_#{entry.id}" do
      click_on "Edit"
    end
    fill_in "Name", with: "New Title"
    click_on "Update Journal entry"
    expect(page).to have_text("Entry updated")
    expect(page).to have_text("New Title")
  end

  it "attributes agent-authored entries to the agent's display name" do
    maree = create(:agent, slug: "maree", name: "Marée")
    create(:journal_entry, trip: trip, author: maree.user,
                           name: "Visited Mont Saint-Michel")

    visit trip_path(trip)

    within "article", text: "Visited Mont Saint-Michel" do
      expect(page).to have_text("Marée")
    end
  end

  it "deletes a journal entry from the trip page", :js do
    entry = create(:journal_entry, trip: trip, author: admin,
                                   name: "Deletable")
    visit trip_path(trip)
    within "#journal_entry_#{entry.id}" do
      click_on "Read more"
      accept_confirm { click_on "Delete" }
    end
    expect(page).to have_text("Entry deleted")
    expect(page).to have_no_text("Deletable")
  end
end
