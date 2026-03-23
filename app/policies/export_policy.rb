# frozen_string_literal: true

class ExportPolicy < ApplicationPolicy
  def index?
    superadmin? || member?
  end

  def create?
    (superadmin? || member?) && trip.commentable?
  end

  def new?
    create?
  end

  def show?
    superadmin? || own_export?
  end

  def download?
    show?
  end

  private

  def trip
    record.is_a?(Export) ? record.trip : record
  end

  def trip_membership
    return unless user

    trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def own_export?
    record.is_a?(Export) && record.user_id == user&.id
  end
end
