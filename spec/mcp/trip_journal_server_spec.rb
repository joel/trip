# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripJournalServer do
  let(:expected_tools) do
    [
      Tools::CreateJournalEntry,
      Tools::UpdateJournalEntry,
      Tools::ListJournalEntries,
      Tools::CreateComment,
      Tools::AddReaction,
      Tools::UpdateTrip,
      Tools::TransitionTrip,
      Tools::ToggleChecklistItem,
      Tools::ListChecklists,
      Tools::GetTripStatus,
      Tools::AddJournalImages,
      Tools::UploadJournalImages,
      Tools::GetJournalEntry,
      Tools::ListTrips,
      Tools::ListComments,
      Tools::ListReactions,
      Tools::DeleteJournalEntry,
      Tools::UpdateComment,
      Tools::DeleteComment,
      Tools::CreateChecklist
    ]
  end

  describe ".build" do
    it "creates an MCP server" do
      expect(described_class.build).to be_a(MCP::Server)
    end

    it "registers exactly the expected tools" do
      expect(described_class::TOOLS).to match_array(expected_tools)
    end
  end

  describe ".instructions_for" do
    it "personalises the instructions with the agent's name" do
      agent = build(:agent, name: "Marée")
      expect(described_class.instructions_for(agent))
        .to include("You are Marée")
    end

    it "falls back to generic phrasing when no agent is given" do
      expect(described_class.instructions_for(nil))
        .to include("You are an AI travel assistant")
    end
  end
end
