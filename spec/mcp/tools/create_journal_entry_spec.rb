# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::CreateJournalEntry do
  let!(:trip) { create(:trip, :started) }

  describe ".call" do
    it "creates a journal entry with actor attribution" do
      result = described_class.call(
        name: "Day 1 in Paris",
        entry_date: Date.current.to_s,
        trip_id: trip.id,
        actor_type: "Jack",
        actor_id: "jack"
      )

      expect(result).to be_a(MCP::Tool::Response)
      data = JSON.parse(result.content.first[:text])
      expect(data["name"]).to eq("Day 1 in Paris")
      expect(data["actor_type"]).to eq("Jack")

      entry = JournalEntry.find(data["id"])
      expect(entry.actor_type).to eq("Jack")
      expect(entry.actor_id).to eq("jack")
      expect(entry.author.email).to eq("jack@system.local")
    end

    it "resolves active trip when trip_id is omitted" do
      result = described_class.call(
        name: "Auto-resolved", entry_date: Date.current.to_s
      )

      data = JSON.parse(result.content.first[:text])
      expect(data["trip_id"]).to eq(trip.id)
    end

    it "returns error when no active trip and trip_id omitted" do
      trip.update!(state: :planning)

      result = described_class.call(
        name: "No trip", entry_date: Date.current.to_s
      )

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("No active trip")
    end

    it "returns idempotent response for duplicate telegram_message_id" do
      first = described_class.call(
        name: "Telegram entry", entry_date: Date.current.to_s,
        trip_id: trip.id, telegram_message_id: "tg-123"
      )
      first_data = JSON.parse(first.content.first[:text])

      second = described_class.call(
        name: "Different name", entry_date: Date.current.to_s,
        trip_id: trip.id, telegram_message_id: "tg-123"
      )
      second_data = JSON.parse(second.content.first[:text])

      expect(second_data["id"]).to eq(first_data["id"])
      expect(JournalEntry.where(telegram_message_id: "tg-123").count).to eq(1)
    end
  end
end
