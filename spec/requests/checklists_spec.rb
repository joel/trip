# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/checklists" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }

  before { stub_current_user(admin) }

  describe "GET index" do
    it "renders the checklists" do
      get trip_checklists_path(trip)
      expect(response).to be_successful
    end
  end

  describe "GET show" do
    it "renders a checklist" do
      checklist = create(:checklist, trip: trip)
      get trip_checklist_path(trip, checklist)
      expect(response).to be_successful
    end
  end

  describe "GET new" do
    it "renders the new form" do
      get new_trip_checklist_path(trip)
      expect(response).to be_successful
    end
  end

  describe "POST create" do
    it "creates a checklist" do
      expect do
        post trip_checklists_path(trip),
             params: { checklist: { name: "Packing" } }
      end.to change(Checklist, :count).by(1)
    end

    it "rejects invalid params" do
      post trip_checklists_path(trip),
           params: { checklist: { name: "" } }
      expect(response).to have_http_status(
        :unprocessable_content
      )
    end
  end

  describe "PATCH update" do
    it "updates a checklist" do
      checklist = create(:checklist, trip: trip)
      patch trip_checklist_path(trip, checklist),
            params: { checklist: { name: "Updated" } }
      expect(checklist.reload.name).to eq("Updated")
    end
  end

  describe "DELETE destroy" do
    it "deletes a checklist" do
      checklist = create(:checklist, trip: trip)
      expect do
        delete trip_checklist_path(trip, checklist)
      end.to change(Checklist, :count).by(-1)
    end
  end

  describe "authorization" do
    let(:viewer_user) { create(:user) }

    before do
      create(:trip_membership, trip: trip, user: viewer_user,
                               role: :viewer)
      stub_current_user(viewer_user)
    end

    it "denies viewer access to index" do
      get trip_checklists_path(trip)
      expect(response).to have_http_status(:forbidden)
    end

    it "denies viewer to create" do
      post trip_checklists_path(trip),
           params: { checklist: { name: "Nope" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
