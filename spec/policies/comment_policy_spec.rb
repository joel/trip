# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: contributor)
  end
  let(:comment) do
    create(:comment, journal_entry: entry, user: contributor)
  end

  before do
    create(:trip_membership, trip: trip, user: contributor,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#show?" do
    it "allows superadmin" do
      expect(described_class.new(comment, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows member" do
      expect(described_class.new(comment, user: viewer_user)
        .apply(:show?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(comment, user: outsider)
        .apply(:show?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(comment, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows contributor on commentable trip" do
      expect(described_class.new(comment, user: contributor)
        .apply(:create?)).to be(true)
    end

    it "allows viewer on commentable trip" do
      viewer_comment = build(
        :comment, journal_entry: entry, user: viewer_user
      )
      expect(described_class.new(viewer_comment, user: viewer_user)
        .apply(:create?)).to be(true)
    end

    it "allows member on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(comment, user: contributor)
        .apply(:create?)).to be(true)
    end

    it "denies member on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(comment, user: contributor)
        .apply(:create?)).to be(false)
    end

    it "denies member on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(comment, user: contributor)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(comment, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies superadmin on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(comment, user: admin)
        .apply(:create?)).to be(false)
    end

    it "denies non-member" do
      expect(described_class.new(comment, user: outsider)
        .apply(:create?)).to be(false)
    end
  end

  describe "#update?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(comment, user: admin)
        .apply(:update?)).to be(true)
    end

    it "allows own comment author" do
      expect(described_class.new(comment, user: contributor)
        .apply(:update?)).to be(true)
    end

    it "denies other member" do
      expect(described_class.new(comment, user: viewer_user)
        .apply(:update?)).to be(false)
    end

    it "denies author on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(comment, user: contributor)
        .apply(:update?)).to be(false)
    end

    it "denies superadmin on archived trip" do
      trip.update!(state: :archived)
      expect(described_class.new(comment, user: admin)
        .apply(:update?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin on commentable trip" do
      expect(described_class.new(comment, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "allows own comment author" do
      expect(described_class.new(comment, user: contributor)
        .apply(:destroy?)).to be(true)
    end

    it "denies other member" do
      expect(described_class.new(comment, user: viewer_user)
        .apply(:destroy?)).to be(false)
    end

    it "denies superadmin on cancelled trip" do
      trip.update!(state: :cancelled)
      expect(described_class.new(comment, user: admin)
        .apply(:destroy?)).to be(false)
    end
  end
end
