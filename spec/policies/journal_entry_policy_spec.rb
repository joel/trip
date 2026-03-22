# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:author) { create(:user) }
  let(:other_contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:entry) { create(:journal_entry, trip: trip, author: author) }

  before do
    create(:trip_membership, trip: trip, user: author,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: other_contributor,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#show?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows trip member" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:show?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(entry, user: outsider)
        .apply(:show?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows contributor on writable trip" do
      expect(described_class.new(entry, user: author)
        .apply(:create?)).to be(true)
    end

    it "denies contributor on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(entry, user: author)
        .apply(:create?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#edit?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:edit?)).to be(true)
    end

    it "allows author (contributor)" do
      expect(described_class.new(entry, user: author)
        .apply(:edit?)).to be(true)
    end

    it "denies other contributor (not author)" do
      expect(described_class.new(entry, user: other_contributor)
        .apply(:edit?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:edit?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "allows author" do
      expect(described_class.new(entry, user: author)
        .apply(:destroy?)).to be(true)
    end

    it "denies other contributor" do
      expect(described_class.new(entry, user: other_contributor)
        .apply(:destroy?)).to be(false)
    end
  end
end
