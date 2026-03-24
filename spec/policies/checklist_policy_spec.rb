# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChecklistPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:checklist) { create(:checklist, trip: trip) }

  before do
    create(:trip_membership, trip: trip, user: contributor,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(checklist, user: admin)
        .apply(:index?)).to be(true)
    end

    it "allows member" do
      expect(described_class.new(checklist, user: viewer_user)
        .apply(:index?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(checklist, user: outsider)
        .apply(:index?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin on writable trip" do
      expect(described_class.new(checklist, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows contributor on writable trip" do
      expect(described_class.new(checklist, user: contributor)
        .apply(:create?)).to be(true)
    end

    it "denies viewer" do
      expect(described_class.new(checklist, user: viewer_user)
        .apply(:create?)).to be(false)
    end

    it "denies contributor on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(checklist, user: contributor)
        .apply(:create?)).to be(false)
    end

    it "denies contributor on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(checklist, user: contributor)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(checklist, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(checklist, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(checklist, user: admin)
        .apply(:create?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin on writable trip" do
      expect(described_class.new(checklist, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "allows contributor on writable trip" do
      expect(described_class.new(checklist, user: contributor)
        .apply(:destroy?)).to be(true)
    end

    it "denies viewer" do
      expect(described_class.new(checklist, user: viewer_user)
        .apply(:destroy?)).to be(false)
    end

    it "denies superadmin on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(checklist, user: admin)
        .apply(:destroy?)).to be(false)
    end
  end
end
