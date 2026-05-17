# frozen_string_literal: true

class TripPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    superadmin? || member?
  end

  # Trip photo gallery — visible to anyone who can see the trip.
  def gallery?
    show?
  end

  def create?
    superadmin?
  end

  def new?
    create?
  end

  def edit?
    superadmin? || contributor?
  end

  def update?
    edit?
  end

  def destroy?
    superadmin?
  end

  def transition?
    superadmin?
  end

  private

  def trip_membership
    return unless user && record.is_a?(Trip)

    record.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end
end
