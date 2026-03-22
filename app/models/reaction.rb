# frozen_string_literal: true

class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  validates :emoji, presence: true
  validates :emoji, uniqueness: {
    scope: %i[reactable_type reactable_id user_id]
  }

  def trip
    case reactable
    when Trip then reactable
    when JournalEntry then reactable.trip
    when Comment then reactable.journal_entry.trip
    end
  end
end
