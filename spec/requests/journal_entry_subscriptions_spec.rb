# frozen_string_literal: true

require "rails_helper"

RSpec.describe "JournalEntrySubscriptions" do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "POST /trips/:trip_id/journal_entries/:id/subscription" do
    before { stub_current_user(admin) }

    it "creates a subscription" do
      expect do
        post trip_journal_entry_subscription_path(trip, entry)
      end.to change(JournalEntrySubscription, :count).by(1)

      expect(response).to redirect_to(
        trip_path(trip, anchor: "journal_entry_#{entry.id}")
      )
    end

    it "is idempotent" do
      create(:journal_entry_subscription,
             user: admin, journal_entry: entry)

      expect do
        post trip_journal_entry_subscription_path(trip, entry)
      end.not_to change(JournalEntrySubscription, :count)
    end

    it "responds with turbo_stream" do
      post trip_journal_entry_subscription_path(trip, entry),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
      expect(response.body).to include(
        "journal_entry_#{entry.id}_mute"
      )
    end
  end

  describe "DELETE /trips/:trip_id/journal_entries/:id/subscription" do
    before { stub_current_user(admin) }

    it "removes the subscription" do
      create(:journal_entry_subscription,
             user: admin, journal_entry: entry)

      expect do
        delete trip_journal_entry_subscription_path(trip, entry)
      end.to change(JournalEntrySubscription, :count).by(-1)

      expect(response).to redirect_to(
        trip_path(trip, anchor: "journal_entry_#{entry.id}")
      )
    end

    it "handles missing subscription gracefully" do
      expect do
        delete trip_journal_entry_subscription_path(trip, entry)
      end.not_to change(JournalEntrySubscription, :count)

      expect(response).to redirect_to(
        trip_path(trip, anchor: "journal_entry_#{entry.id}")
      )
    end

    it "responds with turbo_stream" do
      create(:journal_entry_subscription,
             user: admin, journal_entry: entry)

      delete trip_journal_entry_subscription_path(trip, entry),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
      expect(response.body).to include(
        "journal_entry_#{entry.id}_mute"
      )
    end
  end

  describe "authorization" do
    it "allows trip members to subscribe" do
      member = create(:user)
      create(:trip_membership, trip: trip, user: member)
      stub_current_user(member)

      expect do
        post trip_journal_entry_subscription_path(trip, entry)
      end.to change(JournalEntrySubscription, :count).by(1)
    end

    it "allows viewers to subscribe" do
      viewer = create(:user)
      create(:trip_membership, trip: trip, user: viewer,
                               role: :viewer)
      stub_current_user(viewer)

      expect do
        post trip_journal_entry_subscription_path(trip, entry)
      end.to change(JournalEntrySubscription, :count).by(1)
    end

    it "allows members on finished trips to subscribe" do
      trip.update!(state: :finished)
      member = create(:user)
      create(:trip_membership, trip: trip, user: member)
      stub_current_user(member)

      expect do
        post trip_journal_entry_subscription_path(trip, entry)
      end.to change(JournalEntrySubscription, :count).by(1)
    end

    it "forbids non-members from subscribing" do
      outsider = create(:user)
      stub_current_user(outsider)

      post trip_journal_entry_subscription_path(trip, entry)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "unauthenticated access" do
    before { stub_current_user(nil) }

    it "returns unauthorized for create" do
      post trip_journal_entry_subscription_path(trip, entry)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
