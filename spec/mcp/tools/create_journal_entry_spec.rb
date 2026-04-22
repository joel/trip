# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::CreateJournalEntry do
  let!(:trip) { create(:trip, :started) }
  let(:agent) { create(:agent) }
  let(:context) { { agent: agent } }

  describe ".call" do
    it "creates a journal entry attributed to the agent's user" do
      result = described_class.call(
        name: "Day 1 in Paris",
        entry_date: Date.current.to_s,
        trip_id: trip.id,
        server_context: context
      )

      expect(result).to be_a(MCP::Tool::Response)
      data = JSON.parse(result.content.first[:text])
      expect(data["name"]).to eq("Day 1 in Paris")

      entry = JournalEntry.find(data["id"])
      expect(entry.author).to eq(agent.user)
      expect(entry.author.email).to eq(agent.user.email)
    end

    it "resolves active trip when trip_id is omitted" do
      result = described_class.call(
        name: "Auto-resolved", entry_date: Date.current.to_s,
        server_context: context
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["trip_id"]).to eq(trip.id)
    end

    it "returns error when no active trip and trip_id omitted" do
      trip.update!(state: :planning)

      result = described_class.call(
        name: "No trip", entry_date: Date.current.to_s,
        server_context: context
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("No active trip")
    end

    it "rejects writes to non-writable trips" do
      cancelled_trip = create(:trip, :cancelled)

      result = described_class.call(
        name: "Should fail", entry_date: Date.current.to_s,
        trip_id: cancelled_trip.id,
        server_context: context
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not writable")
    end

    it "returns idempotent response for duplicate telegram_message_id" do
      first = described_class.call(
        name: "Telegram entry", entry_date: Date.current.to_s,
        trip_id: trip.id, telegram_message_id: "tg-123",
        server_context: context
      )
      first_data = JSON.parse(first.content.first[:text])

      second = described_class.call(
        name: "Different name", entry_date: Date.current.to_s,
        trip_id: trip.id, telegram_message_id: "tg-123",
        server_context: context
      )
      second_data = JSON.parse(second.content.first[:text])

      expect(second_data["id"]).to eq(first_data["id"])
      expect(JournalEntry.where(telegram_message_id: "tg-123").count).to eq(1)
    end

    it "returns error when server_context lacks an agent" do
      result = described_class.call(
        name: "Orphaned", entry_date: Date.current.to_s,
        trip_id: trip.id, server_context: {}
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("No agent in server context")
    end
  end
end
