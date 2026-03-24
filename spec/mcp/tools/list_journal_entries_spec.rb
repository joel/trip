# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::ListJournalEntries do
  let(:trip) { create(:trip, :started) }

  before do
    create_list(:journal_entry, 3, trip: trip)
  end

  describe ".call" do
    it "returns paginated entries" do
      result = described_class.call(trip_id: trip.id, limit: 2, offset: 0)

      data = JSON.parse(result.content.first[:text])
      expect(data["entries"].size).to eq(2)
      expect(data["total"]).to eq(3)
    end

    it "supports offset pagination" do
      result = described_class.call(trip_id: trip.id, limit: 10, offset: 2)

      data = JSON.parse(result.content.first[:text])
      expect(data["entries"].size).to eq(1)
    end

    it "resolves active trip when trip_id is omitted" do
      result = described_class.call

      data = JSON.parse(result.content.first[:text])
      expect(data["total"]).to eq(3)
    end
  end
end
