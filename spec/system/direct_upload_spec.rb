# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Active Storage Direct Upload" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  before { login_as(user: admin) }

  it "wires the entry image field for direct upload" do
    visit new_trip_journal_entry_path(trip)
    field = find("input[type='file'][name='journal_entry[images][]']",
                 visible: :all)
    expect(field["data-direct-upload-url"])
      .to end_with("/rails/active_storage/direct_uploads")
  end

  it "uploads an image via direct upload and attaches it", :js do
    visit new_trip_journal_entry_path(trip)
    fill_in "Name", with: "Beach day"
    fill_in "Entry date", with: Date.current.to_s
    attach_file "journal_entry[images][]",
                Rails.root.join("spec/fixtures/files/pixel.png")
    click_on "Create Journal entry"

    expect(page).to have_text("Entry created")
    entry = trip.journal_entries.find_by!(name: "Beach day")
    expect(entry.images).to be_attached
    expect(entry.images.first.filename.to_s).to eq("pixel.png")
  end
end
