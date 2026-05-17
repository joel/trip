# frozen_string_literal: true

class JournalEntriesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry, only: %i[edit update destroy]
  before_action :authorize_journal_entry!

  def new
    @journal_entry = @trip.journal_entries.new(
      entry_date: Date.current
    )
    render Views::JournalEntries::New.new(
      trip: @trip, journal_entry: @journal_entry
    )
  end

  def edit
    render Views::JournalEntries::Edit.new(
      trip: @trip, journal_entry: @journal_entry
    )
  end

  def create
    result = JournalEntries::Create.new.call(
      params: journal_entry_params, trip: @trip, user: current_user
    )
    case result
    in Dry::Monads::Success(entry)
      attach_uploaded_videos(entry)
      redirect_to trip_path(@trip, anchor: dom_id(entry)),
                  notice: "Entry created."
    in Dry::Monads::Failure(errors)
      @journal_entry = @trip.journal_entries.new(journal_entry_params)
      merge_errors(@journal_entry, errors)
      render Views::JournalEntries::New.new(
        trip: @trip, journal_entry: @journal_entry
      ), status: :unprocessable_content
    end
  end

  def update
    result = JournalEntries::Update.new.call(
      journal_entry: @journal_entry, params: journal_entry_params
    )
    case result
    in Dry::Monads::Success(entry)
      attach_uploaded_videos(entry)
      redirect_to trip_path(@trip, anchor: dom_id(entry)),
                  notice: "Entry updated."
    in Dry::Monads::Failure(errors)
      merge_errors(@journal_entry, errors)
      render Views::JournalEntries::Edit.new(
        trip: @trip, journal_entry: @journal_entry
      ), status: :unprocessable_content
    end
  end

  def destroy
    JournalEntries::Delete.new.call(journal_entry: @journal_entry)
    redirect_to @trip, notice: "Entry deleted.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_journal_entry
    @journal_entry = @trip.journal_entries.find(params[:id])
  end

  def authorize_journal_entry!
    authorize!(@journal_entry || @trip.journal_entries.new)
  end

  def journal_entry_params
    params.expect(journal_entry: [
                    :name, :description, :entry_date,
                    :location_name, :latitude, :longitude,
                    :body, { images: [] }
                  ])
  end

  # video_uploads are direct-upload signed blob ids — not a model
  # attribute, so they are handled separately from journal_entry_params
  # (which is assigned straight onto the record).
  def attach_uploaded_videos(entry)
    signed_ids = params.dig(:journal_entry, :video_uploads)
    return if signed_ids.blank?

    JournalEntries::AttachUploadedVideos.new.call(
      journal_entry: entry,
      signed_ids: Array(signed_ids)
    )
  end

  def merge_errors(record, errors)
    record.errors.merge!(errors) if errors.respond_to?(:each)
  end
end
