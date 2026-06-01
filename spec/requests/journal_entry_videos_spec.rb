# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/journal_entries/:id/videos" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "DELETE destroy" do
    it "soft-removes the video from the kept scope" do
      stub_current_user(admin)
      video = create(:journal_entry_video, journal_entry: entry)
      expect do
        delete trip_journal_entry_video_path(trip, entry, video)
      end.to change { JournalEntryVideo.exists?(video.id) }.from(true).to(false)
      expect(JournalEntryVideo.with_discarded.find(video.id).discarded?).to be(true)
    end

    it "denies a non-member" do
      outsider = create(:user)
      stub_current_user(outsider)
      video = create(:journal_entry_video, journal_entry: entry)
      delete trip_journal_entry_video_path(trip, entry, video)
      expect(response).to have_http_status(:forbidden)
      expect(JournalEntryVideo.exists?(video.id)).to be(true)
    end
  end

  describe "PATCH restore" do
    it "restores a discarded video" do
      stub_current_user(admin)
      video = create(:journal_entry_video, :discarded, journal_entry: entry)
      patch restore_trip_journal_entry_video_path(trip, entry, video)
      expect(JournalEntryVideo.exists?(video.id)).to be(true)
    end
  end
end
