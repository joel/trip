# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/journal_entries/:id/images" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:entry) { create(:journal_entry, :with_images, trip: trip, author: admin) }
  let(:blob) { entry.images.first.blob }

  describe "DELETE destroy" do
    it "soft-removes the image (detach + retain blob)" do
      stub_current_user(admin)
      expect do
        delete trip_journal_entry_image_path(trip, entry, blob.signed_id)
      end.to change { entry.reload.images.count }.from(1).to(0)
         .and change(DetachedAttachment, :count).by(1)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    end

    it "denies a non-member" do
      outsider = create(:user)
      stub_current_user(outsider)
      delete trip_journal_entry_image_path(trip, entry, blob.signed_id)
      expect(response).to have_http_status(:forbidden)
      expect(entry.reload.images.count).to eq(1)
    end
  end

  describe "PATCH restore" do
    it "re-attaches the image and clears the retention record" do
      stub_current_user(admin)
      JournalEntries::RemoveImage.new.call(journal_entry: entry, signed_id: blob.signed_id)
      detached = DetachedAttachment.last
      patch restore_trip_journal_entry_image_path(trip, entry, detached)
      expect(entry.reload.images.count).to eq(1)
      expect(DetachedAttachment.exists?(detached.id)).to be(false)
    end
  end
end
