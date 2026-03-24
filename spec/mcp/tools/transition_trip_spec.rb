# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::TransitionTrip do
  let(:trip) { create(:trip, :started) }

  describe ".call" do
    it "transitions the trip to a new state" do
      result = described_class.call(
        trip_id: trip.id, new_state: "finished"
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["state"]).to eq("finished")
      expect(trip.reload.state).to eq("finished")
    end

    it "returns error for invalid transition" do
      result = described_class.call(
        trip_id: trip.id, new_state: "archived"
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("Cannot transition")
    end
  end
end
