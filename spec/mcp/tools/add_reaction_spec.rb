# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::AddReaction do
  let(:entry) { create(:journal_entry) }
  let(:agent) { create(:agent) }
  let(:context) { { agent: agent } }

  describe ".call" do
    it "adds a reaction attributed to the agent's user" do
      result = described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup",
        server_context: context
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["action"]).to eq("added")
      expect(data["emoji"]).to eq("thumbsup")

      reaction = Reaction.find(data["id"])
      expect(reaction.user).to eq(agent.user)
    end

    it "removes a reaction when toggled twice" do
      described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup",
        server_context: context
      )

      result = described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup",
        server_context: context
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["action"]).to eq("removed")
    end

    it "rejects reactions on non-commentable trips" do
      entry.trip.update!(state: :archived)

      result = described_class.call(
        journal_entry_id: entry.id, emoji: "thumbsup",
        server_context: context
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not commentable")
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent", emoji: "thumbsup",
        server_context: context
      )

      expect(result.error?).to be true
    end
  end
end
