# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#index?" do
    it "allows any authenticated user" do
      expect(described_class.new(trip, user: outsider)
        .apply(:index?)).to be(true)
    end
  end

  describe "#show?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows contributor member" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:show?)).to be(true)
    end

    it "allows viewer member" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:show?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:show?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:create?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:create?)).to be(false)
    end

    it "denies outsider" do
      expect(described_class.new(trip, user: outsider)
        .apply(:create?)).to be(false)
    end
  end

  describe "#edit?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:edit?)).to be(true)
    end

    it "allows contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:edit?)).to be(true)
    end

    it "denies viewer" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:edit?)).to be(false)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:edit?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:destroy?)).to be(false)
    end
  end

  describe "#transition?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:transition?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:transition?)).to be(false)
    end
  end
end
