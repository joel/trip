# frozen_string_literal: true

require "rails_helper"

# Phase 26 — per-item media soft-delete + restore, end-to-end through the UI:
# remove one image / one video from an entry, see it disappear, then restore it
# from the Activity feed.
RSpec.describe "Per-item media soft-delete and restore", :js do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  # Run the audit job inline so the removal row reaches the feed (mirrors
  # spec/system/audit_logs_spec.rb).
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    example.run
    ActiveJob::Base.queue_adapter = adapter
  end

  def entry_dom_id(entry)
    "##{ActionView::RecordIdentifier.dom_id(entry)}"
  end

  def click_remove
    accept_confirm { click_on "Remove", match: :first }
  end

  # The floating PWA install banner can overlay the feed and intercept the
  # click, so remove it first.
  def click_restore
    page.execute_script(
      "document.querySelector('[data-pwa-target=\"banner\"]')?.remove()"
    )
    click_on "Restore", match: :first
  end

  it "removes an image then restores it from the Activity feed" do
    entry = create(:journal_entry, :with_images, trip: trip, author: admin,
                                                 name: "Photos day")
    blob_id = entry.images.first.blob.id

    visit trip_path(trip)
    within entry_dom_id(entry) do
      click_on "Read more"
      click_remove
    end

    # Blob retained (not purged) even though detached.
    expect(page).to have_text("Image removed")
    expect(entry.reload.images.count).to eq(0)
    expect(ActiveStorage::Blob.exists?(blob_id)).to be(true)

    visit trip_audit_logs_path(trip)
    expect(page).to have_text("removed an image")
    click_restore

    expect(page).to have_text("Image restored")
    expect(entry.reload.images.count).to eq(1)
  end

  it "removes a video then restores it from the Activity feed" do
    entry = create(:journal_entry, :with_video, trip: trip, author: admin,
                                                name: "Surf day")
    video = entry.videos.first

    visit trip_path(trip)
    within entry_dom_id(entry) do
      click_on "Read more"
      click_remove
    end

    expect(page).to have_text("Video removed")
    expect(entry.reload.videos.count).to eq(0)
    expect(JournalEntryVideo.with_discarded.find(video.id).discarded?).to be(true)

    visit trip_audit_logs_path(trip)
    expect(page).to have_text("removed a video")
    click_restore

    expect(page).to have_text("Video restored")
    expect(entry.reload.videos.count).to eq(1)
  end
end
