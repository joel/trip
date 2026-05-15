# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::Update do
  let(:entry) { create(:journal_entry, name: "Old Title") }

  it "emits journal_entry.updated with a changes diff" do
    allow(Rails.event).to receive(:notify)

    described_class.new.call(
      journal_entry: entry, params: { name: "New Title" }
    )

    expect(Rails.event).to have_received(:notify).with(
      "journal_entry.updated",
      journal_entry_id: entry.id,
      trip_id: entry.trip_id,
      changes: hash_including("name" => ["Old Title", "New Title"])
    )
  end

  it "returns failure with invalid params" do
    result = described_class.new.call(
      journal_entry: entry, params: { name: "" }
    )
    expect(result).to be_failure
  end
end
