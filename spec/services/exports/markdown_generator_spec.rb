# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exports::MarkdownGenerator do
  let(:admin) { create(:user, :superadmin, name: "Admin") }
  let(:trip) do
    create(:trip, :with_dates, name: "Test Trip",
                               description: "A trip")
  end
  let(:export) { create(:export, trip: trip, user: admin) }

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

    it "produces a valid ZIP with expected structure" do
      result = described_class.new(export).call
      entries = []
      Zip::File.open(result.path) do |zip|
        zip.each { |e| entries << e.name }
      end

      expect(entries).to include("_index.md")
      expect(entries.any? { |e| e.end_with?(".md") && e != "_index.md" }).to be(true)
      result.close!
    end

    it "includes trip metadata in index" do
      result = described_class.new(export).call
      Zip::File.open(result.path) do |zip|
        index = zip.read("_index.md")
        expect(index).to include("Test Trip")
        expect(index).to include("title:")
      end
      result.close!
    end
  end
end
