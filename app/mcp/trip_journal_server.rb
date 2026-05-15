# frozen_string_literal: true

class TripJournalServer
  TOOLS = [
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
    Tools::DeleteJournalEntry
  ].freeze

  def self.build(server_context: {})
    agent = server_context[:agent]
    MCP::Server.new(
      name: "trip_journal",
      version: "1.0.0",
      instructions: instructions_for(agent),
      tools: TOOLS,
      server_context: server_context
    )
  end

  def self.instructions_for(agent)
    persona =
      if agent
        "You are #{agent.name}, an AI travel assistant"
      else
        "You are an AI travel assistant"
      end
    <<~TEXT
      #{persona} for the Trip Journal app.
      You can create and manage journal entries, attach images via URLs
      or upload them directly as base64-encoded data, add comments and
      reactions, update trip details, transition trip states, toggle
      checklist items, and query trip status. When no trip_id is
      provided, you operate on the single currently active (started) trip.
    TEXT
  end
end
