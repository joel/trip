# frozen_string_literal: true

class AuditLogsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip

  RESTORABLE_TYPES = {
    "Trip" => Trip, "JournalEntry" => JournalEntry, "Comment" => Comment
  }.freeze

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
      show_low_signal: @show_low_signal,
      restorable: build_restorable(@audit_logs)
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

  # Maps auditable_id => the currently-discarded record, for *.deleted feed
  # rows the user may restore. Batch-loaded per type (no N+1 across the feed).
  def build_restorable(logs)
    ids_by_type = deletion_ids_by_type(logs)
    RESTORABLE_TYPES.each_with_object({}) do |(type, klass), acc|
      discarded_records(klass, ids_by_type[type]).find_each do |record|
        acc[record.id] = record if restorable?(record)
      end
    end
  end

  def deletion_ids_by_type(logs)
    logs.select { |l| l.action.to_s.end_with?(".deleted") }
        .group_by(&:auditable_type)
  end

  def discarded_records(klass, logs)
    ids = logs&.map(&:auditable_id)
    return klass.none if ids.blank?

    klass.with_discarded.where(id: ids).where.not(discarded_at: nil)
  end

  # Offer restore only when the parent chain is kept (so the path and policy
  # resolve, and we don't surface a child buried under a discarded parent) and
  # the user is authorised.
  def restorable?(record)
    parent_kept = case record
                  when JournalEntry then record.trip.present?
                  when Comment then record.journal_entry.present?
                  else true
                  end
    parent_kept && allowed_to?(:restore?, record)
  end
end
