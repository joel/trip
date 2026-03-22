# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trip do
  describe "validations" do
    it "requires name" do
      trip = described_class.new(name: nil)
      expect(trip).not_to be_valid
      expect(trip.errors[:name]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to created_by user" do
      trip = create(:trip)
      expect(trip.created_by).to be_a(User)
    end

    it "has many trip_memberships" do
      trip = create(:trip)
      create(:trip_membership, trip: trip)
      expect(trip.trip_memberships.count).to eq(1)
    end

    it "has many members through trip_memberships" do
      trip = create(:trip)
      user = create(:user)
      create(:trip_membership, trip: trip, user: user)
      expect(trip.members).to include(user)
    end

    it "has many journal_entries" do
      trip = create(:trip)
      create(:journal_entry, trip: trip)
      expect(trip.journal_entries.count).to eq(1)
    end
  end

  describe "enum states" do
    it "defaults to planning" do
      trip = create(:trip)
      expect(trip).to be_planning
    end

    it "supports all states" do
      %i[planning started cancelled finished archived].each do |state|
        trip = build(:trip, state: state)
        expect(trip.state.to_sym).to eq(state)
      end
    end
  end

  describe "#transition_to!" do
    it "transitions from planning to started" do
      trip = create(:trip)
      trip.transition_to!(:started)
      expect(trip).to be_started
    end

    it "transitions from planning to cancelled" do
      trip = create(:trip)
      trip.transition_to!(:cancelled)
      expect(trip).to be_cancelled
    end

    it "transitions from started to finished" do
      trip = create(:trip, :started)
      trip.transition_to!(:finished)
      expect(trip).to be_finished
    end

    it "transitions from finished to archived" do
      trip = create(:trip, :finished)
      trip.transition_to!(:archived)
      expect(trip).to be_archived
    end

    it "transitions from cancelled to planning" do
      trip = create(:trip, :cancelled)
      trip.transition_to!(:planning)
      expect(trip).to be_planning
    end

    it "raises on invalid transition" do
      trip = create(:trip)
      expect { trip.transition_to!(:finished) }.to raise_error(
        Trip::InvalidTransitionError,
        "Cannot transition from planning to finished"
      )
    end

    it "raises when transitioning from archived" do
      trip = create(:trip, :archived)
      expect { trip.transition_to!(:planning) }.to raise_error(
        Trip::InvalidTransitionError
      )
    end
  end

  describe "#can_transition_to?" do
    it "returns true for valid transitions" do
      trip = build(:trip, state: :planning)
      expect(trip.can_transition_to?(:started)).to be(true)
      expect(trip.can_transition_to?(:cancelled)).to be(true)
    end

    it "returns false for invalid transitions" do
      trip = build(:trip, state: :planning)
      expect(trip.can_transition_to?(:finished)).to be(false)
      expect(trip.can_transition_to?(:archived)).to be(false)
    end
  end

  describe "#writable?" do
    it "returns true for planning" do
      expect(build(:trip, state: :planning)).to be_writable
    end

    it "returns true for started" do
      expect(build(:trip, state: :started)).to be_writable
    end

    it "returns false for finished" do
      expect(build(:trip, state: :finished)).not_to be_writable
    end

    it "returns false for archived" do
      expect(build(:trip, state: :archived)).not_to be_writable
    end
  end

  describe "#commentable?" do
    it "returns true for planning" do
      expect(build(:trip, state: :planning)).to be_commentable
    end

    it "returns true for started" do
      expect(build(:trip, state: :started)).to be_commentable
    end

    it "returns true for finished" do
      expect(build(:trip, state: :finished)).to be_commentable
    end

    it "returns false for cancelled" do
      expect(build(:trip, state: :cancelled)).not_to be_commentable
    end

    it "returns false for archived" do
      expect(build(:trip, state: :archived)).not_to be_commentable
    end
  end

  describe "derived dates" do
    let(:trip) { create(:trip) }

    it "returns start_date when explicitly set" do
      trip.update!(start_date: Date.new(2026, 1, 1))
      expect(trip.effective_start_date).to eq(Date.new(2026, 1, 1))
    end

    it "derives start date from earliest journal entry" do
      create(:journal_entry, trip: trip, entry_date: Date.new(2026, 3, 5))
      create(:journal_entry, trip: trip, entry_date: Date.new(2026, 3, 1))
      expect(trip.effective_start_date).to eq(Date.new(2026, 3, 1))
    end

    it "returns nil when no entries and no explicit date" do
      expect(trip.effective_start_date).to be_nil
    end
  end
end
