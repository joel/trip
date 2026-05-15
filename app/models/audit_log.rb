# frozen_string_literal: true

# Append-only record of a single domain action. Written asynchronously by
# RecordAuditLogJob (never on the request path) and read join-free thanks to
# the denormalised actor_label / summary / metadata columns, so the row stays
# readable even after its trip, actor, or target is destroyed.
class AuditLog < ApplicationRecord
  LOW_SIGNAL_ACTIONS = %w[
    reaction.created reaction.removed checklist_item.toggled
  ].freeze

  belongs_to :trip, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  enum :source, { web: 0, mcp: 1, telegram: 2, system: 3 }

  validates :actor_label, :action, :summary, :event_uid,
            :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }
  scope :for_trip, ->(trip) { where(trip_id: trip.id) }
  scope :app_wide, -> { where(trip_id: nil) }
  scope :high_signal, -> { where.not(action: LOW_SIGNAL_ACTIONS) }

  def low_signal?
    LOW_SIGNAL_ACTIONS.include?(action)
  end

  # Append-only: a persisted audit row is immutable. This blocks updates and
  # destroys without affecting the initial create!.
  def readonly?
    persisted?
  end
end
