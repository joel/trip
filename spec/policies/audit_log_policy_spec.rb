# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLogPolicy do
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
    it "allows a superadmin" do
      expect(described_class.new(trip, user: admin).apply(:index?))
        .to be(true)
    end

    it "allows a trip contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:index?)).to be(true)
    end

    it "denies a trip viewer" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:index?)).to be(false)
    end

    it "denies a non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:index?)).to be(false)
    end

    it "denies an anonymous user" do
      expect(described_class.new(trip, user: nil).apply(:index?))
        .to be(false)
    end
  end
end
