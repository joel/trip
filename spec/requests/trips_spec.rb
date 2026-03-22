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

  describe "unauthenticated access" do
    before { stub_current_user(nil) }

    it "returns unauthorized" do
      get trips_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
