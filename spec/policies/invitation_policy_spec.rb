# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvitationPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:guest) { create(:user) }
  let(:invitation) { create(:invitation) }

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(invitation, user: admin).apply(:index?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(invitation, user: guest).apply(:index?)).to be(false)
    end
  end

  describe "#new?" do
    it "allows superadmin" do
      expect(described_class.new(invitation, user: admin).apply(:new?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(invitation, user: guest).apply(:new?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(invitation, user: admin).apply(:create?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(invitation, user: guest).apply(:create?)).to be(false)
    end
  end
end
