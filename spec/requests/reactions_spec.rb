# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/journal_entries/:id/reactions" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  before { stub_current_user(admin) }

  describe "POST create (toggle)" do
    it "creates a reaction" do
      expect do
        post trip_journal_entry_reactions_path(trip, entry),
             params: { emoji: "thumbsup" }
      end.to change(Reaction, :count).by(1)
    end

    it "removes reaction on second toggle" do
      create(:reaction, reactable: entry, user: admin,
                        emoji: "thumbsup")
      expect do
        post trip_journal_entry_reactions_path(trip, entry),
             params: { emoji: "thumbsup" }
      end.to change(Reaction, :count).by(-1)
    end
  end

  describe "POST create (turbo_stream)" do
    let(:turbo_headers) do
      { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "returns turbo_stream response" do
      post trip_journal_entry_reactions_path(trip, entry),
           params: { emoji: "thumbsup" },
           headers: turbo_headers
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
    end

    it "replaces the reaction summary" do
      post trip_journal_entry_reactions_path(trip, entry),
           params: { emoji: "thumbsup" },
           headers: turbo_headers
      expect(response.body).to include("<turbo-stream")
      expect(response.body).to include(
        "reaction_summary_#{entry.id}"
      )
    end
  end

  describe "authorization" do
    let(:outsider) { create(:user) }

    it "denies non-member" do
      stub_current_user(outsider)
      post trip_journal_entry_reactions_path(trip, entry),
           params: { emoji: "thumbsup" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
