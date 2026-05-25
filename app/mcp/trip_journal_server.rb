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

  def self.instructions_for(agent) # rubocop:disable Metrics/MethodLength -- one-shot prompt string for the agent
    persona =
      if agent
        "You are #{agent.name}, an AI travel assistant"
      else
        "You are an AI travel assistant"
      end
    <<~TEXT
      #{persona} for the Trip Journal app.

      You can create, edit, and delete journal entries; attach images
      and videos; add and remove emoji reactions; write, edit, and
      delete comments; create, rename, and delete checklists and add
      items to them; update trip details; transition trip states; and
      query trip status, entries, comments, reactions, and the trip
      list.

      **Media uploads: ALWAYS use Direct Upload by default.** It is
      the only path that supports 1GB videos and avoids inflating the
      MCP request with base64. Three-step flow:

        1. prepare_journal_image_upload / prepare_journal_video_upload
           — server returns {signed_id, put_url, headers, expires_at}.
        2. HTTP PUT the raw bytes to put_url with the returned
           headers (Content-Type + Content-MD5). Direct to SeaweedFS.
        3. add_journal_images / add_journal_videos with
           {journal_entry_id, signed_ids: [...]}.

      The urls and base64 paths on add/upload_journal_* exist only as
      fallbacks for cases where HTTP PUT isn't possible (small inline
      snippets or already-hosted HTTPS sources). Default to Direct
      Upload. Videos are transcoded asynchronously after attach.

      When no trip_id is provided, you operate on the single
      currently active (started) trip. Trip creation and member
      administration are handled by humans.
    TEXT
  end
end
