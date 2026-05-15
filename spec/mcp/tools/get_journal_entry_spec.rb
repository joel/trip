# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::GetJournalEntry do
  let(:trip) { create(:trip, :started) }
  let(:entry) do
    create(:journal_entry, :with_location, trip: trip,
                                           name: "Day 1",
                                           description: "Arrival")
  end

  describe ".call" do
    it "returns the entry core fields with HTML body" do
      entry.body = "Hello <strong>world</strong>"
      entry.save!

      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["id"]).to eq(entry.id)
      expect(data["name"]).to eq("Day 1")
      expect(data["body"]).to include("<strong>world</strong>")
      expect(data["location_name"]).to eq("Paris, France")
      expect(data["description"]).to eq("Arrival")
      expect(data["trip_id"]).to eq(trip.id)
    end

    it "returns zero counts and no images for a bare entry" do
      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["comments_count"]).to eq(0)
      expect(data["reactions_count"]).to eq(0)
      expect(data["image_urls"]).to eq([])
    end

    it "counts comments and reactions" do
      create(:comment, journal_entry: entry)
      create(:reaction, reactable: entry)

      result = described_class.call(journal_entry_id: entry.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["comments_count"]).to eq(1)
      expect(data["reactions_count"]).to eq(1)
    end

    it "returns image URLs when images are attached" do
      with_images = create(:journal_entry, :with_images, trip: trip)

      result = described_class.call(journal_entry_id: with_images.id)
      data = JSON.parse(result.content.first[:text])

      expect(data["image_urls"].size).to eq(1)
      expect(data["image_urls"].first).to include("rails/active_storage")
    end

    it "returns error for nonexistent entry" do
      result = described_class.call(journal_entry_id: "missing-id")

      expect(result.error?).to be true
      expect(result.content.first[:text]).to include("not found")
    end
  end
end
