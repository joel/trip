# frozen_string_literal: true

class ChecklistItemPolicy < ApplicationPolicy
  def create?
    (superadmin? || contributor?) && trip.writable?
  end

  def toggle?
    (superadmin? || contributor?) && trip.writable?
  end

  def destroy?
    (superadmin? || contributor?) && trip.writable?
  end

  private

  def trip
    record.checklist_section.checklist.trip
  end

  def trip_membership
    return unless user

    trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end
end
