# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyTripStateChangeJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:member) { create(:user) }

  before do
    create(:trip_membership, trip: trip, user: member,
                             role: :contributor)
  end

  it "sends email to each trip member" do
    expect do
      described_class.perform_now(
        trip.id, "planning", "started"
      )
    end.to change {
      ActionMailer::Base.deliveries.count
    }.by(1)
  end

  it "does not raise for missing trip" do
    expect do
      described_class.perform_now(
        "nonexistent", "planning", "started"
      )
    end.not_to raise_error
  end
end
