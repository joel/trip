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

  describe "soft deletion (discard)" do
    it "default scope hides discarded entries; with_discarded sees them" do
      entry = create(:journal_entry, :discarded)
      expect(described_class.exists?(entry.id)).to be(false)
      expect(described_class.with_discarded.exists?(entry.id)).to be(true)
    end

    it "cascades discard to its comments" do
      entry = create(:journal_entry)
      comment = create(:comment, journal_entry: entry)
      entry.discard!
      expect(comment.reload.discarded?).to be(true)
    end

    it "undiscard restores the entry only, not its comments" do
      entry = create(:journal_entry)
      comment = create(:comment, journal_entry: entry)
      entry.discard!
      entry.undiscard!
      expect(described_class.exists?(entry.id)).to be(true)
      expect(comment.reload.discarded?).to be(true)
    end
  end

  describe "versioning (paper_trail)" do
    let(:user) { create(:user) }

    around do |example|
      Current.set(actor: user, source: :web) { example.run }
    end

    it "records a version when the title changes" do
      entry = JournalEntries::Create.new.call(
        params: { name: "Title v1", entry_date: Date.current },
        trip: create(:trip), user: user
      ).value!
      expect do
        JournalEntries::Update.new.call(journal_entry: entry,
                                        params: { name: "Title v2" })
      end
        .to change { entry.versions.count }.by(1)
      expect(entry.versions.last.whodunnit).to eq(user.id)
    end

    it "reify restores the prior title" do
      entry = JournalEntries::Create.new.call(
        params: { name: "Original", entry_date: Date.current },
        trip: create(:trip), user: user
      ).value!
      JournalEntries::Update.new.call(journal_entry: entry,
                                      params: { name: "Edited" })
      expect(entry.versions.last.reify.name).to eq("Original")
    end

    it "versions the rich-text body content separately" do
      entry = JournalEntries::Create.new.call(
        params: { name: "E", entry_date: Date.current,
                  body: "<div>Body v1</div>" },
        trip: create(:trip), user: user
      ).value!
      rich_text = ActionText::RichText.find_by(record: entry, name: "body")
      expect do
        JournalEntries::Update.new.call(
          journal_entry: entry, params: { body: "<div>Body v2</div>" }
        )
      end.to change { rich_text.reload.versions.count }.by(1)
    end

    it "does not create a title version on discard" do
      entry = JournalEntries::Create.new.call(
        params: { name: "Keep", entry_date: Date.current },
        trip: create(:trip), user: user
      ).value!
      expect { entry.discard! }.not_to(change { entry.versions.count })
    end
  end
end
