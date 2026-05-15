# frozen_string_literal: true

# Authorized against the Trip (not an AuditLog row). The trip-scoped
# Activity feed is visible only to superadmins and trip contributors;
# viewers/guests are hidden entirely (the controller turns the denial
# into a 404 rather than the app-wide 403).
class AuditLogPolicy < ApplicationPolicy
  def index?
    superadmin? || contributor?
  end

  private

  def trip
    record
  end

  def trip_membership
    return unless user && trip.is_a?(Trip)

    trip.trip_memberships.find_by(user: user)
  end

  def contributor?
    trip_membership&.contributor?
  end
end
