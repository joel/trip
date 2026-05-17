# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips" do
  let!(:admin) { create(:user, :superadmin) }

  before { stub_current_user(admin) }

  describe "GET /trips" do
    it "renders a successful response" do
      create(:trip, created_by: admin)
      get trips_path
      expect(response).to be_successful
    end
  end

  describe "GET /trips/:id" do
    it "renders the trip" do
      trip = create(:trip, created_by: admin)
      get trip_path(trip)
      expect(response).to be_successful
    end
  end

  describe "GET /trips/new" do
    it "renders the new form" do
      get new_trip_path
      expect(response).to be_successful
    end
  end

  describe "POST /trips" do
    it "creates a trip with valid params" do
      expect do
        post trips_path, params: { trip: { name: "My Trip" } }
      end.to change(Trip, :count).by(1)

      expect(response).to redirect_to(trip_path(Trip.last))
    end

    it "rejects invalid params" do
      post trips_path, params: { trip: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /trips/:id" do
    it "updates the trip" do
      trip = create(:trip, created_by: admin)
      patch trip_path(trip), params: { trip: { name: "Updated" } }
      expect(trip.reload.name).to eq("Updated")
      expect(response).to redirect_to(trip_path(trip))
    end
  end

  describe "DELETE /trips/:id" do
    it "destroys the trip" do
      trip = create(:trip, created_by: admin)
      expect do
        delete trip_path(trip)
      end.to change(Trip, :count).by(-1)
    end
  end

  describe "PATCH /trips/:id/transition" do
    it "transitions with valid state and members" do
      trip = create(:trip, created_by: admin)
      create(:trip_membership, trip: trip, user: admin)
      patch transition_trip_path(trip), params: { state: "started" }
      expect(trip.reload).to be_started
      expect(response).to redirect_to(trip_path(trip))
    end

    it "rejects transition without members" do
      trip = create(:trip, created_by: admin)
      patch transition_trip_path(trip), params: { state: "started" }
      expect(trip.reload).to be_planning
      expect(response).to redirect_to(trip_path(trip))
    end
  end

  describe "authorization" do
    let!(:viewer_user) { create(:user) }
    let!(:trip) { create(:trip, created_by: admin) }

    before do
      create(:trip_membership, trip: trip, user: viewer_user,
                               role: :viewer)
    end

    context "when logged in as viewer" do
      before { stub_current_user(viewer_user) }

      it "allows show" do
        get trip_path(trip)
        expect(response).to be_successful
      end

      it "forbids edit" do
        get edit_trip_path(trip)
        expect(response).to have_http_status(:forbidden)
      end

      it "forbids create" do
        post trips_path, params: { trip: { name: "No" } }
        expect(response).to have_http_status(:forbidden)
      end

      it "forbids destroy" do
        delete trip_path(trip)
        expect(response).to have_http_status(:forbidden)
      end

      it "forbids transition" do
        patch transition_trip_path(trip),
              params: { state: "started" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when logged in as non-member" do
      let!(:outsider) { create(:user) }

      before { stub_current_user(outsider) }

      it "forbids show" do
        get trip_path(trip)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /trips/:id/gallery" do
    let!(:gallery_trip) { create(:trip, created_by: admin) }

    context "when logged in as a member" do
      before { stub_current_user(admin) }

      it "renders the gallery with the trip photos" do
        create(:journal_entry, :with_images, trip: gallery_trip,
                                             author: admin)
        get gallery_trip_path(gallery_trip)
        expect(response).to be_successful
        expect(response.body).to include("Gallery")
        expect(response.body).to include('data-controller="lightbox"')
      end

      it "shows the empty state when there are no photos" do
        create(:journal_entry, trip: gallery_trip, author: admin)
        get gallery_trip_path(gallery_trip)
        expect(response).to be_successful
        expect(response.body).to include("No photos yet")
      end
    end

    context "when logged in as a viewer member" do
      let!(:viewer_user) { create(:user) }

      before do
        create(:trip_membership, trip: gallery_trip,
                                 user: viewer_user, role: :viewer)
        stub_current_user(viewer_user)
      end

      it "is visible to viewers" do
        get gallery_trip_path(gallery_trip)
        expect(response).to be_successful
      end
    end

    context "when logged in as a non-member" do
      before { stub_current_user(create(:user)) }

      it "is forbidden" do
        get gallery_trip_path(gallery_trip)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "unauthenticated access" do
    before { stub_current_user(nil) }

    it "returns unauthorized" do
      get trips_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
