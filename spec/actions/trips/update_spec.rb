# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trips::Update do
  let(:trip) { create(:trip, name: "Old Name") }

  it "updates the trip" do
    result = described_class.new.call(trip: trip, params: { name: "New Name" })
    expect(result).to be_success
    expect(trip.reload.name).to eq("New Name")
  end

  it "emits trip.updated with a changes diff" do
    allow(Rails.event).to receive(:notify)

    described_class.new.call(trip: trip, params: { name: "New Name" })

    expect(Rails.event).to have_received(:notify).with(
      "trip.updated",
      trip_id: trip.id,
      changes: hash_including("name" => ["Old Name", "New Name"])
    )
  end

  it "excludes timestamps from the diff" do
    allow(Rails.event).to receive(:notify)
    described_class.new.call(trip: trip, params: { name: "X" })
    expect(Rails.event).to have_received(:notify) do |_name, payload|
      expect(payload[:changes].keys).not_to include("updated_at", "created_at")
    end
  end

  it "returns failure with invalid params" do
    result = described_class.new.call(trip: trip, params: { name: "" })
    expect(result).to be_failure
  end
end
