# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Journal entry videos" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  it "plays a ready video inline in the entry card", :js do
    entry = create(:journal_entry, :with_video, trip: trip,
                                                author: admin,
                                                name: "Surf day")
    visit trip_path(trip)
    within "##{ActionView::RecordIdentifier.dom_id(entry)}" do
      click_on "Read more"
      expect(page).to have_css(
        "video[data-controller='video-player'] source", visible: :all
      )
    end
  end

  it "shows an optimizing placeholder while pending", :js do
    entry = create(:journal_entry, trip: trip, author: admin,
                                   name: "Processing entry")
    create(:journal_entry_video, journal_entry: entry,
                                 status: :pending)
    visit trip_path(trip)
    within "##{ActionView::RecordIdentifier.dom_id(entry)}" do
      click_on "Read more"
      expect(page).to have_text("Optimizing video")
    end
  end

  it "shows the video in the unified trip gallery", :js do
    create(:journal_entry, :with_video, trip: trip, author: admin,
                                        name: "Clip entry")
    visit gallery_trip_path(trip)
    trigger = first("button[data-lightbox-target='trigger']")
    expect(trigger).to be_present
    trigger.click
    expect(page).to have_css("[role='dialog']", visible: :visible)
    expect(page).to have_css(
      "[data-lightbox-video]", visible: :all
    )
  end
end
