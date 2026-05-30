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

  describe "restore controls on deletion rows" do
    it "shows a Restore button for a discarded entry the user may restore" do
      stub_current_user(admin)
      entry = create(:journal_entry, :discarded, trip: trip)
      create(:audit_log, trip: trip, action: "journal_entry.deleted",
                         auditable: entry, summary: "Joel deleted a journal entry")

      get trip_audit_logs_path(trip)

      expect(response.body).to include("Restore")
      expect(response.body)
        .to include(restore_trip_journal_entry_path(trip, entry))
    end

    it "shows no Restore button once the record is no longer discarded" do
      stub_current_user(admin)
      entry = create(:journal_entry, trip: trip)
      create(:audit_log, trip: trip, action: "journal_entry.deleted",
                         auditable: entry, summary: "Joel deleted a journal entry")

      get trip_audit_logs_path(trip)

      expect(response.body)
        .not_to include(restore_trip_journal_entry_path(trip, entry))
    end

    it "attaches Restore only to deletion rows, not other events" do
      stub_current_user(admin)
      entry = create(:journal_entry, :discarded, trip: trip)
      create(:audit_log, trip: trip, action: "journal_entry.deleted",
                         auditable: entry, summary: "Joel deleted a journal entry")
      create(:audit_log, trip: trip, action: "journal_entry.updated",
                         auditable: entry, summary: "Joel updated a journal entry")
      create(:audit_log, trip: trip, action: "journal_entry.restored",
                         auditable: entry, summary: "Joel restored a journal entry")

      get trip_audit_logs_path(trip)

      # One Restore button for the single deletion row, not one per event.
      expect(response.body.scan("Restore").size).to eq(1)
    end

    it "shows no Restore button to a contributor on someone else's entry" do
      stub_current_user(contributor_user)
      entry = create(:journal_entry, :discarded, trip: trip, author: admin)
      create(:audit_log, trip: trip, action: "journal_entry.deleted",
                         auditable: entry, summary: "Joel deleted a journal entry")

      get trip_audit_logs_path(trip)

      expect(response.body)
        .not_to include(restore_trip_journal_entry_path(trip, entry))
    end
  end

  describe "revert controls on update rows" do
    it "shows a Revert button on an update row with a diff" do
      stub_current_user(admin)
      entry = create(:journal_entry, trip: trip, name: "Bar")
      log = create(:audit_log, trip: trip, action: "journal_entry.updated",
                               auditable: entry,
                               metadata: { "changes" => { "name" => %w[Foo Bar] } },
                               summary: "Joel updated a journal entry")

      get trip_audit_logs_path(trip)

      expect(response.body).to include("Revert")
      expect(response.body).to include(revert_trip_audit_log_path(trip, log))
    end

    it "reverts the change by re-applying the old values" do
      stub_current_user(admin)
      entry = create(:journal_entry, trip: trip, name: "Bar")
      log = create(:audit_log, trip: trip, action: "journal_entry.updated",
                               auditable: entry,
                               metadata: { "changes" => { "name" => %w[Foo Bar] } },
                               summary: "Joel updated a journal entry")

      patch revert_trip_audit_log_path(trip, log)

      expect(response).to redirect_to(trip_audit_logs_path(trip))
      expect(entry.reload.name).to eq("Foo")
    end

    it "shows no Revert button on a non-update row" do
      stub_current_user(admin)
      entry = create(:journal_entry, trip: trip)
      create(:audit_log, trip: trip, action: "journal_entry.created",
                         auditable: entry, summary: "Joel created a journal entry")

      get trip_audit_logs_path(trip)

      expect(response.body).not_to include("Revert")
    end

    it "404s when the row is not revertable" do
      stub_current_user(admin)
      entry = create(:journal_entry, trip: trip)
      log = create(:audit_log, trip: trip, action: "journal_entry.created",
                               auditable: entry, summary: "Joel created an entry")

      patch revert_trip_audit_log_path(trip, log)

      expect(response).to have_http_status(:not_found)
    end
  end
end
