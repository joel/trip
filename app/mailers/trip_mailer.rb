# frozen_string_literal: true

class TripMailer < ApplicationMailer
  def member_added(trip_membership_id)
    @membership = TripMembership.find(trip_membership_id)
    @trip = @membership.trip
    @user = @membership.user

    mail(
      to: @user.email,
      subject: "You've been added to #{@trip.name}"
    )
  end
end
