# frozen_string_literal: true

class TripMembershipPolicy < ApplicationPolicy
  def index?
    superadmin? || member_of_trip?
  end

  def create?
    superadmin?
  end

  def new?
    create?
  end

  def destroy?
    superadmin?
  end

  private

  def member_of_trip?
    return false unless user

    record.trip.trip_memberships.exists?(user: user)
  end
end
