# frozen_string_literal: true

class Trip < ApplicationRecord
  VALID_TRANSITIONS = {
    planning: %i[started cancelled],
    started: %i[finished cancelled],
    finished: %i[archived],
    cancelled: %i[planning],
    archived: []
  }.freeze

  class InvalidTransitionError < StandardError; end

  enum :state, {
    planning: 0, started: 1, cancelled: 2, finished: 3, archived: 4
  }

  belongs_to :created_by, class_name: "User"
  has_many :trip_memberships, dependent: :destroy
  has_many :members, through: :trip_memberships, source: :user
  has_many :journal_entries, dependent: :destroy
  has_many :checklists, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy

  validates :name, presence: true

  def transition_to!(new_state)
    new_state = new_state.to_sym
    unless VALID_TRANSITIONS[state.to_sym]&.include?(new_state)
      raise InvalidTransitionError,
            "Cannot transition from #{state} to #{new_state}"
    end
    update!(state: new_state)
  end

  def can_transition_to?(new_state)
    VALID_TRANSITIONS[state.to_sym]&.include?(new_state.to_sym) || false
  end

  def writable?
    planning? || started?
  end

  def commentable?
    planning? || started? || finished?
  end

  def effective_start_date
    start_date || journal_entries.chronological.first&.entry_date
  end

  def effective_end_date
    end_date || journal_entries.chronological.last&.entry_date
  end

  def start_location
    journal_entries.chronological
                   .where.not(location_name: [nil, ""]).first
  end

  def end_location
    journal_entries.chronological
                   .where.not(location_name: [nil, ""]).last
  end
end
