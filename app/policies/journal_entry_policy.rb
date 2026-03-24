# frozen_string_literal: true

class JournalEntryPolicy < ApplicationPolicy
  def show?
    superadmin? || member?
  end

  def create?
    (superadmin? || contributor?) && record.trip.writable?
  end

  def new?
    create?
  end

  def edit?
    (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
  end

  def update?
    edit?
  end

  def destroy?
    (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
  end

  private

  def trip_membership
    return unless user

    record.trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end

  def own_entry?
    record.author_id == user&.id
  end
end
