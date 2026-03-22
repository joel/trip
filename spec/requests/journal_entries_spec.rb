# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/journal_entries" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }

  before { stub_current_user(admin) }

  describe "GET /trips/:trip_id/journal_entries/:id" do
    it "renders the entry" do
      entry = create(:journal_entry, trip: trip, author: admin)
      get trip_journal_entry_path(trip, entry)
      expect(response).to be_successful
    end
  end

  describe "GET /trips/:trip_id/journal_entries/new" do
    it "renders the new form" do
      get new_trip_journal_entry_path(trip)
      expect(response).to be_successful
    end
  end

  describe "POST /trips/:trip_id/journal_entries" do
    it "creates an entry with valid params" do
      expect do
        post trip_journal_entries_path(trip), params: {
          journal_entry: {
            name: "Day 1", entry_date: Date.current.to_s
          }
        }
      end.to change(JournalEntry, :count).by(1)
    end

    it "rejects invalid params" do
      post trip_journal_entries_path(trip), params: {
        journal_entry: { name: "", entry_date: "" }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /trips/:trip_id/journal_entries/:id" do
    it "updates the entry" do
      entry = create(:journal_entry, trip: trip, author: admin)
      patch trip_journal_entry_path(trip, entry), params: {
        journal_entry: { name: "Updated" }
      }
      expect(entry.reload.name).to eq("Updated")
    end
  end

  describe "DELETE /trips/:trip_id/journal_entries/:id" do
    it "destroys the entry" do
      entry = create(:journal_entry, trip: trip, author: admin)
      expect do
        delete trip_journal_entry_path(trip, entry)
      end.to change(JournalEntry, :count).by(-1)
    end
  end

  describe "authorization" do
    let!(:viewer_user) { create(:user) }
    let!(:other_contributor) { create(:user) }
    let!(:entry) { create(:journal_entry, trip: trip, author: admin) }

    before do
      create(:trip_membership, trip: trip, user: viewer_user,
                               role: :viewer)
      create(:trip_membership, trip: trip, user: other_contributor,
                               role: :contributor)
    end

    context "when logged in as viewer" do
      before { stub_current_user(viewer_user) }

      it "allows show" do
        get trip_journal_entry_path(trip, entry)
        expect(response).to be_successful
      end

      it "forbids create" do
        post trip_journal_entries_path(trip), params: {
          journal_entry: {
            name: "No", entry_date: Date.current.to_s
          }
        }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when logged in as other contributor (not author)" do
      before { stub_current_user(other_contributor) }

      it "forbids edit of another's entry" do
        get edit_trip_journal_entry_path(trip, entry)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
