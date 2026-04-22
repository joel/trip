# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "roles" do
    it "defaults new accounts to guest" do
      user = described_class.create!(name: "Guest User", email: "guest@example.com")

      expect(user.roles).to eq([:guest])
      expect(user.role?(:guest)).to be(true)
    end

    it "assigns roles via roles=" do
      user = described_class.new(name: "Contributor User", email: "contrib@example.com")

      user.roles = %i[superadmin contributor]

      expect(user.roles).to contain_exactly(:superadmin, :contributor)
      expect(user.role?(:superadmin)).to be(true)
      expect(user.role?(:guest)).to be(false)
    end

    it "ignores unknown roles" do
      user = described_class.new(name: "Mixed User", email: "mixed@example.com")

      user.roles = %i[superadmin unknown]

      expect(user.roles).to eq([:superadmin])
    end

    it "supports viewer role" do
      user = described_class.new(name: "Viewer User", email: "viewer@example.com")

      user.roles = [:viewer]

      expect(user.role?(:viewer)).to be(true)
      expect(user.role?(:contributor)).to be(false)
    end
  end

  describe "#system_actor?" do
    it "returns true for @system.local emails" do
      user = described_class.new(email: "maree@system.local",
                                 name: "Marée")
      expect(user.system_actor?).to be(true)
    end

    it "returns false for regular emails" do
      user = described_class.new(email: "alice@acme.org",
                                 name: "Alice")
      expect(user.system_actor?).to be(false)
    end

    it "is safe for nil email" do
      user = described_class.new(name: "Unsaved")
      expect(user.system_actor?).to be(false)
    end
  end

  describe "notification cleanup on destroy" do
    it "destroys actor-side notifications when user is deleted" do
      actor = create(:user)
      recipient = create(:user)
      entry = create(:journal_entry)

      create(:notification,
             actor: actor, recipient: recipient,
             notifiable: entry)

      expect { actor.destroy! }.to change(Notification, :count).by(-1)
    end
  end
end
