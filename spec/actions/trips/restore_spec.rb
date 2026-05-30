# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trips::Restore do
  it "restores a discarded trip into the kept scope" do
    trip = create(:trip, :discarded)
    expect { described_class.new.call(trip: trip) }
      .to change { Trip.exists?(trip.id) }.from(false).to(true)
  end

  it "emits trip.restored with the id and name" do
    trip = create(:trip, :discarded, name: "Iceland")
    allow(Rails.event).to receive(:notify)

    described_class.new.call(trip: trip)

    expect(Rails.event).to have_received(:notify).with(
      "trip.restored", trip_id: trip.id, trip_name: "Iceland"
    )
  end
end
