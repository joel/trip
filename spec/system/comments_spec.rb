# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Comments" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, :started, created_by: admin) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  before do
    create(:trip_membership, trip: trip, user: admin,
                             role: :contributor)
    login_as(user: admin)
  end

  it "edits a comment inline" do
    comment = create(:comment, journal_entry: entry,
                               user: admin,
                               body: "Original text")

    visit trip_journal_entry_path(trip, entry)
    expect(page).to have_content("Original text")

    within "#comment_#{comment.id}" do
      find("summary", text: "Edit").click
      fill_in "comment[body]", with: "Updated text"
      click_on "Save"
    end

    expect(page).to have_content("Updated text")
    expect(comment.reload.body).to eq("Updated text")
  end
end
