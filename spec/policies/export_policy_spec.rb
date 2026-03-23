# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExportPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }

  before do
    create(:trip_membership, trip: trip,
                             user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip,
                             user: viewer_user,
                             role: :viewer)
  end

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:index?)).to be(true)
    end

    it "allows member" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:index?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:index?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(trip, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows member on commentable trip" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:create?)).to be(true)
    end

    it "allows viewer member on commentable trip" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:create?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:create?)).to be(false)
    end

    it "denies member on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(trip, user: contributor_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#show?" do
    let(:export) do
      create(:export, trip: trip, user: contributor_user)
    end

    it "allows superadmin" do
      expect(described_class.new(export, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows own export" do
      expect(
        described_class.new(export, user: contributor_user)
          .apply(:show?)
      ).to be(true)
    end

    it "denies other user's export" do
      expect(described_class.new(export, user: viewer_user)
        .apply(:show?)).to be(false)
    end
  end

  describe "#download?" do
    let(:export) do
      create(:export, trip: trip, user: contributor_user)
    end

    it "allows own export" do
      expect(
        described_class.new(export, user: contributor_user)
          .apply(:download?)
      ).to be(true)
    end

    it "denies other user" do
      expect(described_class.new(export, user: viewer_user)
        .apply(:download?)).to be(false)
    end
  end
end
