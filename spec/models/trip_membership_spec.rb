# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripMembership do
  describe "validations" do
    it "enforces uniqueness of user per trip" do
      trip = create(:trip)
      user = create(:user)
      create(:trip_membership, trip: trip, user: user)

      duplicate = build(:trip_membership, trip: trip, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to trip and user" do
      membership = create(:trip_membership)
      expect(membership.trip).to be_a(Trip)
      expect(membership.user).to be_a(User)
    end
  end

  describe "enum roles" do
    it "defaults to contributor" do
      membership = create(:trip_membership)
      expect(membership).to be_contributor
    end

    it "supports viewer role" do
      membership = create(:trip_membership, :viewer)
      expect(membership).to be_viewer
    end
  end
end
