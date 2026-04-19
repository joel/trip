# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripMembershipPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:membership) do
    create(:trip_membership, trip: trip, user: contributor_user)
  end

  before do
    create(:trip_membership, :viewer, trip: trip, user: viewer_user)
  end

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:index?)).to be(true)
    end

    it "allows contributor" do
      expect(described_class.new(membership, user: contributor_user)
        .apply(:index?)).to be(true)
    end

    it "denies viewer" do
      expect(described_class.new(membership, user: viewer_user)
        .apply(:index?)).to be(false)
    end

    it "denies non-member" do
      expect(described_class.new(membership, user: outsider)
        .apply(:index?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:create?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(membership, user: contributor_user)
        .apply(:create?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(membership, user: viewer_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(membership, user: contributor_user)
        .apply(:destroy?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(membership, user: viewer_user)
        .apply(:destroy?)).to be(false)
    end
  end
end
