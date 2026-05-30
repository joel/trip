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
      Checklists::Tools::ToggleItem,
      Checklists::Tools::List,
      Tools::GetTripStatus,
      Tools::AddJournalImages,
      Tools::UploadJournalImages,
      Tools::PrepareJournalImageUpload,
      Tools::AddJournalVideos,
      Tools::UploadJournalVideos,
      Tools::PrepareJournalVideoUpload,
      Tools::GetJournalEntry,
      Tools::ListTrips,
      Tools::ListComments,
      Tools::ListReactions,
      Tools::DeleteJournalEntry,
      Tools::UpdateComment,
      Tools::DeleteComment,
      Checklists::Tools::Create,
      Checklists::Tools::Update,
      Checklists::Tools::Delete,
      Checklists::Tools::CreateItem
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

    it "describes the Phase 20 capabilities and human-only carve-out" do
      text = described_class.instructions_for(nil).gsub(/\s+/, " ")

      expect(text).to include("create, edit, and delete journal entries")
      expect(text).to include("delete comments")
      expect(text).to include("delete checklists")
      expect(text)
        .to include("Trip creation and member administration are " \
                    "handled by humans")
    end

    it "tells agents to default to Direct Upload for media (#172)" do
      text = described_class.instructions_for(nil).gsub(/\s+/, " ")

      expect(text).to include("ALWAYS use Direct Upload by default")
      expect(text).to include("prepare_journal_image_upload")
      expect(text).to include("prepare_journal_video_upload")
      expect(text).to include("signed_ids")
      expect(text).to include("fallbacks")
    end
  end
end
