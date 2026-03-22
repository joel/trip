# frozen_string_literal: true

class ReactionPolicy < ApplicationPolicy
  def create?
    superadmin? || (member? && trip.commentable?)
  end

  def destroy?
    superadmin? || (own_reaction? && trip.commentable?)
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

  def own_reaction?
    member? && record.user_id == user&.id
  end
end
