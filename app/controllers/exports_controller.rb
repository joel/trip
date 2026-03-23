# frozen_string_literal: true

class ExportsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_export, only: %i[show download]

  def index
    authorize! @trip, with: ExportPolicy
    @exports = @trip.exports.where(user: current_user)
                    .recent.includes(:user)
    @exports = @trip.exports.recent.includes(:user) if current_user.role?(:superadmin)
    render Views::Exports::Index.new(
      trip: @trip, exports: @exports
    )
  end

  def show
    authorize! @export
    render Views::Exports::Show.new(
      trip: @trip, export: @export
    )
  end

  def new
    authorize! @trip, with: ExportPolicy
    render Views::Exports::New.new(trip: @trip)
  end

  def create
    authorize! @trip, with: ExportPolicy
    result = ::Exports::RequestExport.new.call(
      trip: @trip, user: current_user,
      format: params[:export][:format]
    )
    case result
    in Dry::Monads::Success(export)
      redirect_to trip_export_path(@trip, export),
                  notice: "Export requested. We'll notify you when it's ready."
    in Dry::Monads::Failure(errors)
      redirect_to new_trip_export_path(@trip),
                  alert: "Could not create export."
    end
  end

  def download
    authorize! @export
    unless @export.completed? && @export.file.attached?
      redirect_to trip_export_path(@trip, @export),
                  alert: "Export is not ready for download."
      return
    end

    redirect_to rails_blob_path(
      @export.file, disposition: "attachment"
    ), allow_other_host: true
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_export
    @export = @trip.exports.find(params[:id])
  end
end
