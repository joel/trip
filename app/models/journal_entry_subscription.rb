# frozen_string_literal: true

class JournalEntrySubscription < ApplicationRecord
  belongs_to :user
  belongs_to :journal_entry

  validates :user_id, uniqueness: { scope: :journal_entry_id }
end
