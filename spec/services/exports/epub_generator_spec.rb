# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exports::EpubGenerator do
  let(:admin) { create(:user, :superadmin, name: "Admin") }
  let(:trip) do
    create(:trip, :with_dates, name: "Test Trip",
                               description: "A trip")
  end
  let(:export) { create(:export, :epub, trip: trip, user: admin) }

  before do
    create(:journal_entry, trip: trip, author: admin,
                           name: "Day One",
                           entry_date: Date.current)
  end

  describe "#call" do
    it "returns a tempfile" do
      result = described_class.new(export).call
      expect(result).to be_a(Tempfile)
      expect(File.exist?(result.path)).to be(true)
      result.close!
    end

    it "produces a file with epub extension" do
      result = described_class.new(export).call
      expect(result.path).to end_with(".epub")
      result.close!
    end
  end
end
