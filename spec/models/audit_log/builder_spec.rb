# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog::Builder do
  def row_for(name, payload)
    described_class.new(name: name, payload: payload).call
  end

  around do |example|
    Current.set(actor: nil, source: :web, request_id: "req-1") { example.run }
  end

  let(:actor) { create(:user, name: "Joel") }
  let(:trip)  { create(:trip, name: "Iceland", created_by: actor) }

  describe "trip events" do
    it "trip.created" do
      Current.actor = actor
      row = row_for("trip.created", trip_id: trip.id)
      expect(row).to include(
        action: "trip.created", trip_id: trip.id, actor_id: actor.id,
        actor_label: "Joel", auditable_type: "Trip", auditable_id: trip.id
      )
      expect(row[:summary]).to eq('Joel created trip "Iceland"')
      expect(row[:event_uid]).to eq("req-1:trip.created:#{trip.id}")
    end

    it "trip.updated renders a diff suffix from changes" do
      Current.actor = actor
      row = row_for("trip.updated",
                    trip_id: trip.id,
                    changes: { "name" => %w[Iceland Norway] })
      expect(row[:summary]).to eq(
        'Joel updated trip "Iceland" — Name: "Iceland" → "Norway"'
      )
      expect(row[:metadata]["changes"]).to eq("name" => %w[Iceland Norway])
    end

    it "trip.state_changed renders a state suffix" do
      Current.actor = actor
      row = row_for("trip.state_changed",
                    trip_id: trip.id, from_state: "planning",
                    to_state: "started")
      expect(row[:summary]).to eq(
        'Joel changed the state of trip "Iceland" — Planning → Started'
      )
    end

    it "trip.deleted keeps trip_id and name from payload after destroy" do
      Current.actor = actor
      row = row_for("trip.deleted",
                    trip_id: trip.id, trip_name: "Iceland")
      trip.destroy!
      expect(row[:trip_id]).to eq(trip.id)
      expect(row[:summary]).to eq('Joel deleted trip "Iceland"')
    end
  end

  describe "journal entry events" do
    let(:entry) do
      create(:journal_entry, trip: trip, author: actor, name: "Day 1")
    end

    it "journal_entry.created uses payload actor_id" do
      row = row_for("journal_entry.created",
                    journal_entry_id: entry.id, trip_id: trip.id,
                    actor_id: actor.id)
      expect(row[:actor_id]).to eq(actor.id)
      expect(row[:summary]).to eq('Joel created journal entry "Day 1"')
    end

    it "journal_entry.deleted degrades gracefully when record is gone" do
      id = entry.id
      entry.destroy!
      Current.actor = actor
      row = row_for("journal_entry.deleted",
                    journal_entry_id: id, trip_id: trip.id)
      expect(row[:summary]).to eq("Joel deleted a journal entry")
      expect(row[:trip_id]).to eq(trip.id)
    end
  end

  describe "comment events" do
    it "comment.created resolves trip via the entry" do
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry, user: actor)
      row = row_for("comment.created",
                    comment_id: comment.id,
                    journal_entry_id: entry.id, actor_id: actor.id)
      expect(row[:trip_id]).to eq(trip.id)
      expect(row[:summary]).to eq("Joel created a comment")
    end

    # Regression (PR #144): comment.deleted is emitted after destroy!,
    # so the comment row is gone — trip scoping must come from the
    # surviving journal entry, not the deleted comment.
    it "comment.deleted keeps trip scoping after the comment is gone" do
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry)
      comment_id = comment.id
      comment.destroy!
      Current.actor = actor

      row = row_for("comment.deleted",
                    comment_id: comment_id, journal_entry_id: entry.id)

      expect(row[:trip_id]).to eq(trip.id)
      expect(row[:summary]).to eq("Joel deleted a comment")
    end
  end

  describe "reaction events (low signal)" do
    it "reaction.created derives trip from the reactable" do
      entry = create(:journal_entry, trip: trip)
      reaction = create(:reaction, reactable: entry, user: actor)
      Current.actor = actor
      row = row_for("reaction.created",
                    reaction_id: reaction.id,
                    reactable_type: "JournalEntry", reactable_id: entry.id)
      expect(row[:trip_id]).to eq(trip.id)
      expect(row[:action]).to eq("reaction.created")
    end

    # Regression (PR #144): reaction.removed is emitted after destroy!,
    # so the reaction row is gone — trip scoping must come from the
    # reactable in the payload.
    it "reaction.removed keeps trip scoping after the reaction is gone" do
      entry = create(:journal_entry, trip: trip)
      reaction = create(:reaction, reactable: entry, user: actor)
      reaction_id = reaction.id
      reaction.destroy!
      Current.actor = actor

      row = row_for("reaction.removed",
                    reaction_id: reaction_id,
                    reactable_type: "JournalEntry", reactable_id: entry.id)

      expect(row[:trip_id]).to eq(trip.id)
      expect(row[:action]).to eq("reaction.removed")
    end

    it "reaction.removed on a comment resolves trip via the comment" do
      entry = create(:journal_entry, trip: trip)
      comment = create(:comment, journal_entry: entry)
      Current.actor = actor

      row = row_for("reaction.removed",
                    reaction_id: SecureRandom.uuid,
                    reactable_type: "Comment", reactable_id: comment.id)

      expect(row[:trip_id]).to eq(trip.id)
    end

    it "reaction.removed on a trip resolves trip from reactable_id" do
      Current.actor = actor
      row = row_for("reaction.removed",
                    reaction_id: SecureRandom.uuid,
                    reactable_type: "Trip", reactable_id: trip.id)
      expect(row[:trip_id]).to eq(trip.id)
    end
  end

  describe "checklist events" do
    it "checklist.updated carries the diff" do
      list = create(:checklist, trip: trip, name: "Packing")
      Current.actor = actor
      row = row_for("checklist.updated",
                    checklist_id: list.id, trip_id: trip.id,
                    changes: { "name" => %w[Packing Gear] })
      expect(row[:summary]).to eq(
        'Joel updated checklist "Packing" — Name: "Packing" → "Gear"'
      )
    end

    it "checklist_item.toggled resolves trip via the checklist" do
      list = create(:checklist, trip: trip)
      Current.actor = actor
      row = row_for("checklist_item.toggled",
                    checklist_item_id: SecureRandom.uuid,
                    checklist_id: list.id)
      expect(row[:trip_id]).to eq(trip.id)
    end
  end

  describe "app-wide events (nil trip)" do
    it "invitation.sent has no trip" do
      Current.actor = actor
      row = row_for("invitation.sent",
                    invitation_id: SecureRandom.uuid, email: "a@b.com")
      expect(row[:trip_id]).to be_nil
      expect(row[:summary]).to eq("Joel sent an invitation to a@b.com")
    end

    it "access_request.approved attributes to the reviewer" do
      row = row_for("access_request.approved",
                    access_request_id: SecureRandom.uuid,
                    email: "x@y.com", reviewer_id: actor.id)
      expect(row[:actor_id]).to eq(actor.id)
      expect(row[:trip_id]).to be_nil
      expect(row[:summary]).to eq(
        "Joel approved access request for x@y.com"
      )
    end

    it "access_request.submitted has no actor (System)" do
      row = row_for("access_request.submitted",
                    access_request_id: SecureRandom.uuid, email: "x@y.com")
      expect(row[:actor_id]).to be_nil
      expect(row[:actor_label]).to eq("System")
    end
  end

  describe "membership events" do
    it "trip_membership.removed names the removed member" do
      member = create(:user, name: "Sam")
      Current.actor = actor
      row = row_for("trip_membership.removed",
                    trip_membership_id: SecureRandom.uuid,
                    trip_id: trip.id, user_id: member.id)
      expect(row[:summary]).to eq("Joel removed Sam from the trip")
    end
  end

  describe "actor labelling" do
    it "labels agent actors with (agent)" do
      agent = create(:agent, name: "Marée")
      Current.actor = agent.user
      row = row_for("trip.created", trip_id: trip.id)
      expect(row[:actor_label]).to eq("Marée (agent)")
    end

    it "tags source from Current" do
      Current.set(actor: actor, source: :mcp, request_id: "r") do
        row = row_for("trip.created", trip_id: trip.id)
        expect(row[:source]).to eq("mcp")
      end
    end
  end

  it "returns nil for an unknown entity" do
    expect(row_for("widget.frobnicated", {})).to be_nil
  end
end
