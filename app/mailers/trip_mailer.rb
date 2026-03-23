# frozen_string_literal: true

class TripMailer < ApplicationMailer
  def state_changed(trip_id, user_id, from_state, to_state)
    @trip = Trip.find_by(id: trip_id)
    @user = User.find_by(id: user_id)
    return unless @trip && @user

    @from_state = from_state
    @to_state = to_state

    mail(
      to: @user.email,
      subject: "#{@trip.name} is now #{@to_state}"
    )
  end

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
