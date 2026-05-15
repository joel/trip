# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/activity" do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:trip) { create(:trip, created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  it "renders the feed for a superadmin" do
    stub_current_user(admin)
    create(:audit_log, trip: trip, summary: "Joel created trip")
    get trip_audit_logs_path(trip)
    expect(response).to be_successful
    expect(response.body).to include("Joel created trip")
    expect(response.body).to include("Activity")
  end

  it "renders the feed for a trip contributor" do
    stub_current_user(contributor_user)
    get trip_audit_logs_path(trip)
    expect(response).to be_successful
  end

  it "returns 404 for a trip viewer (hidden entirely)" do
    stub_current_user(viewer_user)
    get trip_audit_logs_path(trip)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a non-member" do
    stub_current_user(create(:user))
    get trip_audit_logs_path(trip)
    expect(response).to have_http_status(:not_found)
  end

  it "hides low-signal rows by default and shows them when toggled" do
    stub_current_user(admin)
    create(:audit_log, trip: trip, summary: "High signal entry")
    create(:audit_log, :low_signal, trip: trip,
                                    summary: "Low signal reaction")

    get trip_audit_logs_path(trip)
    expect(response.body).to include("High signal entry")
    expect(response.body).not_to include("Low signal reaction")

    get trip_audit_logs_path(trip, low_signal: 1)
    expect(response.body).to include("Low signal reaction")
  end

  it "applies the before cursor" do
    stub_current_user(admin)
    create(:audit_log, trip: trip, summary: "Old row",
                       occurred_at: 3.days.ago)
    create(:audit_log, trip: trip, summary: "Recent row",
                       occurred_at: 1.minute.ago)

    get trip_audit_logs_path(trip, before: 2.days.ago.iso8601)
    expect(response.body).to include("Old row")
    expect(response.body).not_to include("Recent row")
  end
end
