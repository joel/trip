# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trips::TransitionState do
  describe "#call" do
    it "transitions from planning to started with members" do
      trip = create(:trip)
      create(:trip_membership, trip: trip)

      result = described_class.new.call(
        trip: trip, new_state: :started
      )

      expect(result).to be_success
      expect(trip.reload).to be_started
    end

    it "fails planning to started without members" do
      trip = create(:trip)

      result = described_class.new.call(
        trip: trip, new_state: :started
      )

      expect(result).to be_failure
      expect(result.failure).to eq(:requires_members)
    end

    it "fails on invalid transition" do
      trip = create(:trip)

      result = described_class.new.call(
        trip: trip, new_state: :finished
      )

      expect(result).to be_failure
    end

    it "transitions from started to finished" do
      trip = create(:trip, :started)

      result = described_class.new.call(
        trip: trip, new_state: :finished
      )

      expect(result).to be_success
      expect(trip.reload).to be_finished
    end
  end
end
