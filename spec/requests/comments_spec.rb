# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/journal_entries/:id/comments" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  before { stub_current_user(admin) }

  describe "POST create" do
    it "creates a comment" do
      expect do
        post trip_journal_entry_comments_path(trip, entry),
             params: { comment: { body: "Nice!" } }
      end.to change(Comment, :count).by(1)
    end

    it "redirects to trip page with entry anchor" do
      post trip_journal_entry_comments_path(trip, entry),
           params: { comment: { body: "Nice!" } }
      expect(response).to redirect_to(
        trip_path(trip, anchor: "journal_entry_#{entry.id}")
      )
    end
  end

  describe "PATCH update" do
    it "updates own comment" do
      comment = create(:comment, journal_entry: entry,
                                 user: admin)
      patch trip_journal_entry_comment_path(
        trip, entry, comment
      ), params: { comment: { body: "Updated" } }
      expect(comment.reload.body).to eq("Updated")
    end
  end

  describe "DELETE destroy" do
    it "deletes own comment" do
      comment = create(:comment, journal_entry: entry,
                                 user: admin)
      expect do
        delete trip_journal_entry_comment_path(
          trip, entry, comment
        )
      end.to change(Comment, :count).by(-1)
    end
  end

  describe "turbo_stream responses" do
    let(:turbo_headers) do
      { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "appends comment and replaces form on create" do
      post trip_journal_entry_comments_path(trip, entry),
           params: { comment: { body: "Turbo!" } },
           headers: turbo_headers
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
      expect(response.body).to include("comments_#{entry.id}")
      expect(response.body).to include(
        "comment_form_#{entry.id}"
      )
    end

    it "replaces comment card on update" do
      comment = create(:comment, journal_entry: entry,
                                 user: admin)
      patch trip_journal_entry_comment_path(
        trip, entry, comment
      ), params: { comment: { body: "Updated" } },
         headers: turbo_headers
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
      expect(response.body).to include("<turbo-stream")
    end

    it "removes comment card on destroy" do
      comment = create(:comment, journal_entry: entry,
                                 user: admin)
      delete trip_journal_entry_comment_path(
        trip, entry, comment
      ), headers: turbo_headers
      expect(response.media_type).to eq(
        "text/vnd.turbo-stream.html"
      )
      expect(response.body).to include("remove")
    end
  end

  describe "authorization" do
    let(:outsider) { create(:user) }

    it "denies non-member" do
      stub_current_user(outsider)
      post trip_journal_entry_comments_path(trip, entry),
           params: { comment: { body: "Nope" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "denies member on cancelled trip" do
      member = create(:user)
      create(:trip_membership, trip: trip, user: member,
                               role: :contributor)
      stub_current_user(member)
      trip.update!(state: :cancelled)
      post trip_journal_entry_comments_path(trip, entry),
           params: { comment: { body: "Nope" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
