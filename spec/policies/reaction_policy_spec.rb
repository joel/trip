# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReactionPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: contributor)
  end
  let(:reaction) do
    create(:reaction, reactable: entry, user: contributor,
                      emoji: "thumbsup")
  end

  before do
    create(:trip_membership, trip: trip, user: contributor,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#create?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(reaction, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows member on commentable trip" do
      expect(described_class.new(reaction, user: contributor)
        .apply(:create?)).to be(true)
    end

    it "allows viewer on commentable trip" do
      viewer_reaction = build(
        :reaction, reactable: entry, user: viewer_user
      )
      expect(described_class.new(viewer_reaction, user: viewer_user)
        .apply(:create?)).to be(true)
    end

    it "allows on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(reaction, user: contributor)
        .apply(:create?)).to be(true)
    end

    it "denies on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(reaction, user: contributor)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(reaction, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(reaction, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies non-member" do
      expect(described_class.new(reaction, user: outsider)
        .apply(:create?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(reaction, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "allows own reaction" do
      expect(described_class.new(reaction, user: contributor)
        .apply(:destroy?)).to be(true)
    end

    it "denies other member" do
      expect(described_class.new(reaction, user: viewer_user)
        .apply(:destroy?)).to be(false)
    end

    it "denies superadmin on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(reaction, user: admin)
        .apply(:destroy?)).to be(false)
    end
  end
end
