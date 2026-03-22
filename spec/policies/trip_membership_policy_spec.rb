# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripMembershipPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:member_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:membership) do
    create(:trip_membership, trip: trip, user: member_user)
  end

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:index?)).to be(true)
    end

    it "allows trip member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:index?)).to be(true)
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

    it "denies member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "denies member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:destroy?)).to be(false)
    end
  end
end
