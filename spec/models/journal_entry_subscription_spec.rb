# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntrySubscription do
  describe "validations" do
    it "is valid with valid attributes" do
      subscription = build(:journal_entry_subscription)
      expect(subscription).to be_valid
    end

    it "requires unique user per journal entry" do
      entry = create(:journal_entry)
      user = create(:user)
      create(:journal_entry_subscription,
             user: user, journal_entry: entry)

      duplicate = build(:journal_entry_subscription,
                        user: user, journal_entry: entry)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include(
        "has already been taken"
      )
    end
  end

  describe "associations" do
    it "belongs to user" do
      subscription = create(:journal_entry_subscription)
      expect(subscription.user).to be_a(User)
    end

    it "belongs to journal_entry" do
      subscription = create(:journal_entry_subscription)
      expect(subscription.journal_entry).to be_a(JournalEntry)
    end
  end
end
