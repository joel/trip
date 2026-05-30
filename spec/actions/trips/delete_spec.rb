# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trips::Delete do
  it "soft-deletes the trip (removes it from the kept scope)" do
    trip = create(:trip)
    expect { described_class.new.call(trip: trip) }
      .to change(Trip, :count).by(-1)
  end

  it "keeps the row recoverable via with_discarded" do
    trip = create(:trip)
    described_class.new.call(trip: trip)
    expect(Trip.with_discarded.find(trip.id)).to be_discarded
  end

  it "emits trip.deleted with the id and name captured before destroy" do
    trip = create(:trip, name: "Iceland")
    allow(Rails.event).to receive(:notify)

    described_class.new.call(trip: trip)

    expect(Rails.event).to have_received(:notify).with(
      "trip.deleted", trip_id: trip.id, trip_name: "Iceland"
    )
  end
end
