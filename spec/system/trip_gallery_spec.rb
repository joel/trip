# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trip Gallery and Lightbox" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  it "shows a Gallery link on the trip page" do
    visit trip_path(trip)
    expect(page).to have_link("Gallery", href: gallery_trip_path(trip))
  end

  it "renders the empty state when the trip has no photos" do
    visit gallery_trip_path(trip)
    expect(page).to have_text("No photos yet")
  end

  it "opens the lightbox and navigates the trip photo set", :js do
    create(:journal_entry, :with_images, trip: trip, author: admin,
                                         name: "First Stop",
                                         entry_date: Date.new(2026, 5, 1))
    create(:journal_entry, :with_images, trip: trip, author: admin,
                                         name: "Second Stop",
                                         entry_date: Date.new(2026, 5, 2))

    visit gallery_trip_path(trip)
    page.first("button[data-lightbox-target='trigger']").click

    expect(page).to have_css("[role='dialog']", visible: :visible)
    expect(page).to have_css("[data-lightbox-counter]",
                             text: "1 / 2")

    find("button[aria-label='Next image']").click
    expect(page).to have_css("[data-lightbox-counter]",
                             text: "2 / 2")

    find("body").send_keys(:escape)
    expect(page).to have_css("[role='dialog']", visible: :hidden)
  end

  it "opens the lightbox from a journal entry cover image", :js do
    create(:journal_entry, :with_images, trip: trip, author: admin,
                                         name: "Cover Entry")

    visit trip_path(trip)
    find("button[aria-label='View photos for Cover Entry']").click

    expect(page).to have_css("[role='dialog']", visible: :visible)
    expect(page).to have_css("[data-lightbox-counter]",
                             text: "1 / 1")
  end
end
