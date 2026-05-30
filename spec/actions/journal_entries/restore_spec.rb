# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::Restore do
  it "restores a discarded entry into the kept scope" do
    entry = create(:journal_entry, :discarded)
    expect { described_class.new.call(journal_entry: entry) }
      .to change { JournalEntry.exists?(entry.id) }.from(false).to(true)
  end

  it "emits journal_entry.restored with the captured ids" do
    entry = create(:journal_entry, :discarded)
    allow(Rails.event).to receive(:notify)

    described_class.new.call(journal_entry: entry)

    expect(Rails.event).to have_received(:notify).with(
      "journal_entry.restored",
      journal_entry_id: entry.id, trip_id: entry.trip_id
    )
  end
end
