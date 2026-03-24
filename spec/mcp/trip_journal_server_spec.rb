# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripJournalServer do
  describe ".build" do
    it "creates an MCP server with all 11 tools" do
      server = described_class.build
      expect(server).to be_a(MCP::Server)
    end

    it "registers all expected tools" do
      expect(described_class::TOOLS.size).to eq(11)
      expect(described_class::TOOLS).to include(
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
        Tools::AddJournalImages
      )
    end

    it "includes server instructions" do
      expect(described_class::INSTRUCTIONS).to include("Jack")
    end
  end
end
