# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Welcomes" do
  describe "GET /" do
    context "when logged out" do
      it "renders the welcome page" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Welcome to Catalyst")
      end
    end

    context "when logged in" do
      let(:user) { create(:user, :superadmin) }

      before { stub_current_user(user) }

      it "renders the empty-state when the user has no trips" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No trips yet!")
      end

      it "redirects to the trip when the user has exactly one" do
        trip = create(:trip, created_by: user)
        create(:trip_membership, trip: trip, user: user)
        get root_path
        expect(response).to redirect_to(trip_path(trip))
      end

      it "redirects to the started trip when 2+ and one is started" do
        planning = create(:trip, created_by: user)
        create(:trip_membership, trip: planning, user: user)
        started = create(:trip, :started, created_by: user)
        create(:trip_membership, trip: started, user: user)
        get root_path
        expect(response).to redirect_to(trip_path(started))
      end

      it "redirects to the most recently updated started trip" do
        first_started = create(:trip, :started, created_by: user)
        create(:trip_membership, trip: first_started, user: user)
        second_started = create(:trip, :started, created_by: user)
        create(:trip_membership, trip: second_started, user: user)
        first_started.update!(updated_at: 1.minute.from_now)
        get root_path
        expect(response).to redirect_to(trip_path(first_started))
      end

      it "redirects to /trips when 2+ trips and none started" do
        a = create(:trip, created_by: user)
        create(:trip_membership, trip: a, user: user)
        b = create(:trip, created_by: user)
        create(:trip_membership, trip: b, user: user)
        get root_path
        expect(response).to redirect_to(trips_path)
      end
    end
  end

  describe "GET /welcome/home" do
    it "returns http success when logged out" do
      get "/welcome/home"
      expect(response).to have_http_status(:success)
    end
  end
end
