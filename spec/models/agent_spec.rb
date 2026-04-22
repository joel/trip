# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent do
  describe "validations" do
    subject(:agent) { build(:agent) }

    it { is_expected.to be_valid }

    it "requires a slug" do
      agent.slug = nil
      expect(agent).not_to be_valid
      expect(agent.errors[:slug]).to include("can't be blank")
    end

    it "requires a name" do
      agent.name = nil
      expect(agent).not_to be_valid
      expect(agent.errors[:name]).to include("can't be blank")
    end

    it "enforces slug format (lowercase, digits, hyphen, underscore)" do
      ["Jack", "jack!", "jack.1", "jack space"].each do |bad|
        agent.slug = bad
        expect(agent).not_to be_valid,
                             "expected #{bad.inspect} to be invalid"
      end
      %w[jack maree jack-2 trip_bot agent_01].each do |good|
        agent.slug = good
        expect(agent).to be_valid, "expected #{good.inspect} to be valid"
      end
    end

    it "enforces slug uniqueness case-insensitively" do
      create(:agent, slug: "jack")
      dup = build(:agent, slug: "JACK")
      expect(dup).not_to be_valid
      expect(dup.errors[:slug]).to include("has already been taken")
    end

    it "enforces one agent per user" do
      shared_user = create(:user, :system_actor)
      create(:agent, user: shared_user)
      dup = build(:agent, user: shared_user)
      expect(dup).not_to be_valid
      expect(dup.errors[:user_id]).to include("has already been taken")
    end
  end

  describe ".by_slug" do
    let!(:agent) { create(:agent, slug: "maree") }

    it "matches an exact slug" do
      expect(described_class.by_slug("maree")).to eq(agent)
    end

    it "matches case-insensitively" do
      expect(described_class.by_slug("MAREE")).to eq(agent)
    end

    it "returns nil for an unknown slug" do
      expect(described_class.by_slug("ghost")).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.by_slug("")).to be_nil
      expect(described_class.by_slug(nil)).to be_nil
    end
  end

  describe "associations" do
    it "belongs to a user" do
      agent = create(:agent)
      expect(agent.user).to be_a(User)
    end
  end
end
