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

  describe "media cascade-restore (release-scan #1)" do
    it "restores videos discarded by the entry's cascade" do
      entry = create(:journal_entry)
      video = create(:journal_entry_video, journal_entry: entry)
      entry.discard! # cascade-discards the video
      expect(JournalEntryVideo.exists?(video.id)).to be(false)

      described_class.new.call(journal_entry: entry)

      expect(JournalEntryVideo.exists?(video.id)).to be(true)
    end

    it "leaves individually-removed videos removed" do
      entry = create(:journal_entry)
      individually = create(:journal_entry_video, journal_entry: entry)
      cascaded = create(:journal_entry_video, journal_entry: entry)
      # Removed on its own, clearly before the entry was deleted.
      individually.discard!
      individually.update_columns(discarded_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
      entry.discard! # cascade-discards `cascaded` now

      described_class.new.call(journal_entry: entry)

      expect(JournalEntryVideo.exists?(cascaded.id)).to be(true)
      expect(JournalEntryVideo.with_discarded.find(individually.id).discarded?)
        .to be(true)
    end

    it "emits journal_entry_video.restored for each cascade-restored video" do
      entry = create(:journal_entry)
      video = create(:journal_entry_video, journal_entry: entry)
      entry.discard!
      allow(Rails.event).to receive(:notify)

      described_class.new.call(journal_entry: entry)

      expect(Rails.event).to have_received(:notify).with(
        "journal_entry_video.restored",
        hash_including(journal_entry_video_id: video.id, journal_entry_id: entry.id)
      )
    end
  end
end
