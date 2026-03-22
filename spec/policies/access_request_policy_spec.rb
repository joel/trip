# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessRequestPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:guest) { create(:user) }
  let(:access_request) { create(:access_request) }

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(access_request, user: admin).apply(:index?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(access_request, user: guest).apply(:index?)).to be(false)
    end
  end

  describe "#approve?" do
    it "allows superadmin" do
      expect(described_class.new(access_request, user: admin).apply(:approve?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(access_request, user: guest).apply(:approve?)).to be(false)
    end
  end

  describe "#reject?" do
    it "allows superadmin" do
      expect(described_class.new(access_request, user: admin).apply(:reject?)).to be(true)
    end

    it "denies guest" do
      expect(described_class.new(access_request, user: guest).apply(:reject?)).to be(false)
    end
  end
end
