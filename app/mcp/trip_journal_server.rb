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
    Tools::DeleteJournalEntry,
    Tools::UpdateComment,
    Tools::DeleteComment,
    Tools::CreateChecklist,
    Tools::UpdateChecklist,
    Tools::DeleteChecklist,
    Tools::CreateChecklistItem
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
      You can create, edit, and delete journal entries; attach images
      via URLs or upload them directly as base64-encoded data; add and
      remove emoji reactions; write, edit, and delete comments; create,
      rename, and delete checklists and add items to them; update trip
      details; transition trip states; and query trip status, entries,
      comments, reactions, and the trip list. When no trip_id is
      provided, you operate on the single currently active (started)
      trip. Trip creation and member administration are handled by
      humans.
    TEXT
  end
end
