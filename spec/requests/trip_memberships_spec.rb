# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/members" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:member_user) { create(:user) }

  before { stub_current_user(admin) }

  describe "GET /trips/:trip_id/members" do
    it "renders the members list" do
      get trip_trip_memberships_path(trip)
      expect(response).to be_successful
    end
  end

  describe "GET /trips/:trip_id/members/new" do
    it "renders the new form" do
      get new_trip_trip_membership_path(trip)
      expect(response).to be_successful
    end
  end

  describe "POST /trips/:trip_id/members" do
    it "creates a membership" do
      expect do
        post trip_trip_memberships_path(trip), params: {
          trip_membership: {
            user_id: member_user.id, role: "contributor"
          }
        }
      end.to change(TripMembership, :count).by(1)

      expect(response).to redirect_to(
        trip_trip_memberships_path(trip)
      )
    end
  end

  describe "DELETE /trips/:trip_id/members/:id" do
    it "removes a membership" do
      membership = create(:trip_membership, trip: trip,
                                            user: member_user)
      expect do
        delete trip_trip_membership_path(trip, membership)
      end.to change(TripMembership, :count).by(-1)
    end
  end

  describe "authorization" do
    let!(:contributor_user) { create(:user) }

    before do
      create(:trip_membership, trip: trip, user: contributor_user,
                               role: :contributor)
      stub_current_user(contributor_user)
    end

    it "allows index for member" do
      get trip_trip_memberships_path(trip)
      expect(response).to be_successful
    end

    it "forbids create for contributor" do
      post trip_trip_memberships_path(trip), params: {
        trip_membership: {
          user_id: member_user.id, role: "viewer"
        }
      }
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids destroy for contributor" do
      membership = create(:trip_membership, trip: trip,
                                            user: member_user)
      delete trip_trip_membership_path(trip, membership)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
