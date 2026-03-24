# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  def show?
    superadmin? || member?
  end

  def create?
    (superadmin? || member?) && trip.commentable?
  end

  def update?
    (superadmin? || own_comment?) && trip.commentable?
  end

  def destroy?
    (superadmin? || own_comment?) && trip.commentable?
  end

  private

  def trip
    record.journal_entry.trip
  end

  def trip_membership
    return unless user

    trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def own_comment?
    member? && record.user_id == user&.id
  end
end
