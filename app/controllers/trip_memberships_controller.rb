# frozen_string_literal: true

class TripMembershipsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip

  def index
    @memberships = @trip.trip_memberships.includes(:user)
    render Views::TripMemberships::Index.new(
      trip: @trip, memberships: @memberships
    )
  end

  def new
    @membership = @trip.trip_memberships.new
    render Views::TripMemberships::New.new(
      trip: @trip, membership: @membership,
      users: available_users
    )
  end

  def create
    result = TripMemberships::Assign.new.call(
      params: membership_params, trip: @trip
    )
    case result
    in Dry::Monads::Success
      redirect_to trip_trip_memberships_path(@trip),
                  notice: "Member added."
    in Dry::Monads::Failure(errors)
      @membership = @trip.trip_memberships.new(membership_params)
      merge_errors(@membership, errors)
      render Views::TripMemberships::New.new(
        trip: @trip, membership: @membership,
        users: available_users
      ), status: :unprocessable_content
    end
  end

  def destroy
    membership = @trip.trip_memberships.find(params[:id])
    TripMemberships::Remove.new.call(membership: membership)
    redirect_to trip_trip_memberships_path(@trip),
                notice: "Member removed.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def membership_params
    params.expect(trip_membership: %i[user_id role])
  end

  def available_users
    existing_ids = @trip.trip_memberships.pluck(:user_id)
    User.where.not(id: existing_ids).order(:email)
  end

  def merge_errors(record, errors)
    record.errors.merge!(errors) if errors.respond_to?(:each)
  end
end
