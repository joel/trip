# frozen_string_literal: true

class AuditLogsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip

  # Q2 (flag #1): viewers/guests are "hidden entirely" — return 404 for
  # this controller instead of the app-wide 403 so the feed's existence
  # is not disclosed.
  rescue_from ActionPolicy::Unauthorized do
    respond_to do |format|
      format.html { head :not_found }
      format.any { head :not_found }
    end
  end

  def index
    authorize! @trip, with: AuditLogPolicy

    @show_low_signal = params[:low_signal] == "1"
    scope = AuditLog.for_trip(@trip).recent
    scope = scope.high_signal unless @show_low_signal
    scope = before_cursor(scope)
    @audit_logs = scope.limit(50)

    render Views::AuditLogs::Index.new(
      trip: @trip, audit_logs: @audit_logs,
      show_low_signal: @show_low_signal
    )
  end

  private

  def set_trip
    @trip = Trip.find(params.expect(:trip_id))
  end

  def before_cursor(scope)
    return scope if params[:before].blank?

    scope.where(occurred_at: ...(params[:before]))
  end
end
