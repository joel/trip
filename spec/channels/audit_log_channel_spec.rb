# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLogChannel do
  let(:trip) { create(:trip) }

  it "streams for a superadmin" do
    stub_connection current_user: create(:user, :superadmin)
    subscribe(trip_id: trip.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("audit_log:trip_#{trip.id}")
  end

  it "streams for a trip contributor" do
    user = create(:user)
    create(:trip_membership, trip: trip, user: user, role: :contributor)
    stub_connection current_user: user
    subscribe(trip_id: trip.id)
    expect(subscription).to be_confirmed
  end

  it "rejects a trip viewer" do
    user = create(:user)
    create(:trip_membership, trip: trip, user: user, role: :viewer)
    stub_connection current_user: user
    subscribe(trip_id: trip.id)
    expect(subscription).to be_rejected
  end

  it "rejects a non-member" do
    stub_connection current_user: create(:user)
    subscribe(trip_id: trip.id)
    expect(subscription).to be_rejected
  end

  it "rejects when the trip does not exist" do
    stub_connection current_user: create(:user, :superadmin)
    subscribe(trip_id: SecureRandom.uuid)
    expect(subscription).to be_rejected
  end
end
