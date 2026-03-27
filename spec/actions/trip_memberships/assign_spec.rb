# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripMemberships::Assign do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:user) { create(:user) }

  describe "#call" do
    it "assigns a user to a trip" do
      result = described_class.new.call(
        params: { user_id: user.id, role: :contributor },
        trip: trip, actor: admin
      )

      expect(result).to be_success
      membership = result.value!
      expect(membership.user).to eq(user)
      expect(membership.trip).to eq(trip)
      expect(membership).to be_contributor
    end

    it "fails on duplicate membership" do
      create(:trip_membership, trip: trip, user: user)

      result = described_class.new.call(
        params: { user_id: user.id, role: :contributor },
        trip: trip, actor: admin
      )

      expect(result).to be_failure
    end
  end
end
