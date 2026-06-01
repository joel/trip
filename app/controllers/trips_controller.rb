# frozen_string_literal: true

class TripsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip,
                only: %i[show edit update destroy transition gallery]
  before_action :set_discarded_trip, only: %i[restore]
  before_action :authorize_trip!

  def index
    base = current_user.role?(:superadmin) ? Trip.all : current_user.trips
    # Enforce the trash view in the controller, not just by hiding the link:
    # restore is superadmin-only, so a non-restorer requesting ?discarded=1
    # falls back to the kept list (no deletion metadata disclosure).
    @discarded = params[:discarded].present? && allowed_to?(:restore?, Trip)
    # .with_discarded.discarded — a bare .discarded would self-contradict the
    # default kept scope (discarded_at IS NULL AND IS NOT NULL).
    @trips = @discarded ? base.with_discarded.discarded : base
    render Views::Trips::Index.new(
      trips: @trips.order(created_at: :desc), discarded: @discarded
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
                              { images_attachments: :blob },
                              # The card renders each entry's videos (player +
                              # remove control), so eager-load them and their
                              # rendition/poster blobs to avoid an N+1 (Phase 26).
                              { videos: [
                                { web_attachment: :blob },
                                { poster_attachment: :blob }
                              ] },
                              comments: :user
                            )
    render Views::Trips::Show.new(
      trip: @trip, journal_entries: @journal_entries
    )
  end

  def gallery
    @journal_entries = @trip.journal_entries
                            .reverse_chronological
                            .includes(
                              { images_attachments: :blob },
                              { videos: [
                                { web_attachment: :blob },
                                { poster_attachment: :blob }
                              ] }
                            )
    render Views::Trips::Gallery.new(
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
    Trips::Delete.new.call(trip: @trip)
    redirect_to trips_path, notice: "Trip deleted.",
                            status: :see_other
  end

  def restore
    Trips::Restore.new.call(trip: @trip)
    redirect_to trip_path(@trip), notice: "Trip restored."
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

  # Restore targets a soft-deleted trip, hidden by the default kept scope.
  def set_discarded_trip
    @trip = Trip.with_discarded.find(params[:id])
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
