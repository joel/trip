# frozen_string_literal: true

class ChecklistPolicy < ApplicationPolicy
  def index?
    superadmin? || member?
  end

  def show?
    superadmin? || member?
  end

  def create?
    superadmin? || (contributor? && trip.writable?)
  end

  def new?
    create?
  end

  def edit?
    superadmin? || (contributor? && trip.writable?)
  end

  def update?
    edit?
  end

  def destroy?
    superadmin? || (contributor? && trip.writable?)
  end

  private

  def trip
    record.trip
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
