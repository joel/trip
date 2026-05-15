# frozen_string_literal: true

# Per-trip live Activity stream. Authorised with the same policy as the
# HTTP feed so a viewer/non-member cannot subscribe to a trip's audit
# events out of band.
class AuditLogChannel < ApplicationCable::Channel
  def subscribed
    trip = Trip.find_by(id: params[:trip_id])

    if trip && AuditLogPolicy.new(trip, user: current_user).apply(:index?)
      stream_from "audit_log:trip_#{trip.id}"
    else
      reject
    end
  end
end
