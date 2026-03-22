# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::Create do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }

  describe "#call" do
    it "creates an entry with valid params" do
      result = described_class.new.call(
        params: { name: "Day 1", entry_date: Date.current },
        trip: trip,
        user: admin
      )

      expect(result).to be_success
      entry = result.value!
      expect(entry.name).to eq("Day 1")
      expect(entry.trip).to eq(trip)
      expect(entry.author).to eq(admin)
    end

    it "returns failure with missing name" do
      result = described_class.new.call(
        params: { name: "", entry_date: Date.current },
        trip: trip,
        user: admin
      )

      expect(result).to be_failure
    end
  end
end
