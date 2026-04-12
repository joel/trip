# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntry do
  describe "validations" do
    it "requires name" do
      entry = build(:journal_entry, name: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:name]).to include("can't be blank")
    end

    it "requires entry_date" do
      entry = build(:journal_entry, entry_date: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:entry_date]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to trip and author" do
      entry = create(:journal_entry)
      expect(entry.trip).to be_a(Trip)
      expect(entry.author).to be_a(User)
    end
  end

  describe ".chronological" do
    it "orders by entry_date, then created_at, then id" do
      trip = create(:trip)
      older = create(:journal_entry, trip: trip,
                                     entry_date: Date.new(2026, 3, 1))
      newer = create(:journal_entry, trip: trip,
                                     entry_date: Date.new(2026, 3, 5))
      retroactive = create(:journal_entry, trip: trip,
                                           entry_date: Date.new(2026, 3, 1))

      result = trip.journal_entries.chronological
      expect(result.first).to eq(older)
      expect(result.last).to eq(newer)
      expect(result.to_a).to include(retroactive)
    end
  end

  describe ".reverse_chronological" do
    it "orders newest first by entry_date, created_at, id" do
      trip = create(:trip)
      older = create(:journal_entry, trip: trip,
                                     entry_date: Date.new(2026, 3, 1))
      newer = create(:journal_entry, trip: trip,
                                     entry_date: Date.new(2026, 3, 5))

      result = trip.journal_entries.reverse_chronological
      expect(result.first).to eq(newer)
      expect(result.last).to eq(older)
    end
  end
end
