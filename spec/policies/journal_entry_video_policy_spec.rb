# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryVideoPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:author) { create(:user) }
  let(:other_contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:entry) { create(:journal_entry, trip: trip, author: author) }
  let(:video) { create(:journal_entry_video, journal_entry: entry) }

  before do
    create(:trip_membership, trip: trip, user: author, role: :contributor)
    create(:trip_membership, trip: trip, user: other_contributor, role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user, role: :viewer)
  end

  describe "#destroy?" do
    it "allows the entry author (contributor) on a writable trip" do
      expect(described_class.new(video, user: author).apply(:destroy?)).to be(true)
    end

    it "allows a superadmin" do
      expect(described_class.new(video, user: admin).apply(:destroy?)).to be(true)
    end

    it "denies another contributor (not the entry author)" do
      expect(described_class.new(video, user: other_contributor).apply(:destroy?)).to be(false)
    end

    it "denies a viewer" do
      expect(described_class.new(video, user: viewer_user).apply(:destroy?)).to be(false)
    end

    it "denies a non-member" do
      expect(described_class.new(video, user: outsider).apply(:destroy?)).to be(false)
    end

    it "denies when the trip is finished (not writable)" do
      trip.update!(state: :finished)
      expect(described_class.new(video, user: author).apply(:destroy?)).to be(false)
    end
  end

  describe "#restore?" do
    it "mirrors destroy? for the entry author" do
      expect(described_class.new(video, user: author).apply(:restore?)).to be(true)
    end

    it "denies another contributor" do
      expect(described_class.new(video, user: other_contributor).apply(:restore?)).to be(false)
    end
  end
end
