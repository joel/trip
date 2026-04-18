# frozen_string_literal: true

class TripsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip, only: %i[show edit update destroy transition]
  before_action :authorize_trip!

  def index
    @trips = if current_user.role?(:superadmin)
               Trip.all
             else
               current_user.trips
             end
    render Views::Trips::Index.new(
      trips: @trips.order(created_at: :desc)
    )
  end

  def show
    @journal_entries = @trip.journal_entries
                            .reverse_chronological
                            .with_rich_text_body
                            .includes(
                              :author,
                              :reactions,
                              :journal_entry_subscriptions,
                              :images_attachments,
                              comments: :user
                            )
    render Views::Trips::Show.new(
      trip: @trip, journal_entries: @journal_entries
    )
  end

  def new
    @trip = Trip.new
    render Views::Trips::New.new(trip: @trip)
  end

  def edit
    render Views::Trips::Edit.new(trip: @trip)
  end

  def create
    result = Trips::Create.new.call(
      params: trip_params, user: current_user
    )
    case result
    in Dry::Monads::Success(trip)
      redirect_to trip, notice: "Trip created."
    in Dry::Monads::Failure(errors)
      @trip = Trip.new(trip_params)
      merge_errors(@trip, errors)
      render Views::Trips::New.new(trip: @trip),
             status: :unprocessable_content
    end
  end

  def update
    result = Trips::Update.new.call(
      trip: @trip, params: trip_params
    )
    case result
    in Dry::Monads::Success(trip)
      redirect_to trip, notice: "Trip updated."
    in Dry::Monads::Failure(errors)
      merge_errors(@trip, errors)
      render Views::Trips::Edit.new(trip: @trip),
             status: :unprocessable_content
    end
  end

  def destroy
    @trip.destroy!
    redirect_to trips_path, notice: "Trip deleted.",
                            status: :see_other
  end

  def transition
    result = Trips::TransitionState.new.call(
      trip: @trip, new_state: params[:state]
    )
    case result
    in Dry::Monads::Success
      redirect_to @trip, notice: "Trip is now #{@trip.state}."
    in Dry::Monads::Failure(:requires_members)
      redirect_to @trip,
                  alert: "Add at least one member before starting."
    in Dry::Monads::Failure(message)
      redirect_to @trip, alert: message.to_s
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def authorize_trip!
    authorize!(@trip || Trip)
  end

  def trip_params
    params.expect(trip: %i[name description start_date end_date])
  end

  def merge_errors(record, errors)
    record.errors.merge!(errors) if errors.respond_to?(:each)
  end
end
