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
    Tools::GetTripStatus
  ].freeze

  INSTRUCTIONS = <<~TEXT
    You are Jack, an AI travel assistant for the Trip Journal app.
    You can create and manage journal entries, add comments and reactions,
    update trip details, transition trip states, toggle checklist items,
    and query trip status. When no trip_id is provided, you operate on
    the single currently active (started) trip.
  TEXT

  def self.build(server_context: {})
    MCP::Server.new(
      name: "trip_journal",
      version: "1.0.0",
      instructions: INSTRUCTIONS,
      tools: TOOLS,
      server_context: server_context
    )
  end
end
