# frozen_string_literal: true

class TripMailer < ApplicationMailer
  def member_added(trip_membership_id)
    @membership = TripMembership.find_by(id: trip_membership_id)
    return unless @membership

    @trip = @membership.trip
    @user = @membership.user

    mail(
      to: @user.email,
      subject: "You've been added to #{@trip.name}"
    )
  end
end
