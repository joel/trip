# frozen_string_literal: true

class AuditLogsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip

  AUDITABLE_MODELS = {
    "Trip" => Trip, "JournalEntry" => JournalEntry, "Comment" => Comment
  }.freeze

  UPDATE_ACTIONS = {
    "Trip" => ->(rec, params) { Trips::Update.new.call(trip: rec, params:) },
    "JournalEntry" => lambda { |rec, params|
      JournalEntries::Update.new.call(journal_entry: rec, params:)
    },
    "Comment" => ->(rec, params) { Comments::Update.new.call(comment: rec, params:) }
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
      restorable: build_restorable(@audit_logs),
      revertable: build_revertable(@audit_logs)
    )
  end

  # Re-applies the old values recorded in an *.updated row's diff, through the
  # record's normal Update action (so the revert is itself a forward audit +
  # version event). Body rich text is not a column, so it never appears in the
  # diff and is out of scope here.
  def revert
    log = AuditLog.for_trip(@trip).find(params.expect(:id))
    record = revert_target(log)
    return head :not_found unless record

    authorize! record, to: :update?
    apply_revert(log, record)
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
    AUDITABLE_MODELS.each_with_object({}) do |(type, klass), acc|
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

  # Maps audit_log_id => the kept record, for *.updated rows the user may
  # revert. Keyed by log id (not auditable_id): each update row reverts its own
  # diff, so the button is per-event.
  def build_revertable(logs)
    update_logs = logs.select { |l| revertable_action?(l) }
    records = kept_records_by_id(update_logs)
    update_logs.each_with_object({}) do |log, acc|
      record = records[log.auditable_id]
      acc[log.id] = record if record && allowed_to?(:update?, record)
    end
  end

  def revertable_action?(log)
    log.action.to_s.end_with?(".updated") &&
      AUDITABLE_MODELS.key?(log.auditable_type) &&
      diff_for(log).present?
  end

  def kept_records_by_id(logs)
    logs.group_by(&:auditable_type).each_with_object({}) do |(type, ls), acc|
      AUDITABLE_MODELS[type].where(id: ls.map(&:auditable_id))
                            .find_each { |r| acc[r.id] = r }
    end
  end

  # The audit row stores changes as { field => [old, new] }; reverting re-applies
  # the old values.
  def revert_target(log)
    return nil unless revertable_action?(log)

    AUDITABLE_MODELS[log.auditable_type].find_by(id: log.auditable_id)
  end

  def apply_revert(log, record)
    old_values = diff_for(log).transform_values { |(old, _new)| old }
    result = UPDATE_ACTIONS.fetch(log.auditable_type).call(record, old_values)
    case result
    in Dry::Monads::Success
      redirect_to trip_audit_logs_path(@trip), notice: "Change reverted."
    in Dry::Monads::Failure
      redirect_to trip_audit_logs_path(@trip),
                  alert: "Could not revert that change."
    end
  end

  def diff_for(log)
    log.metadata.is_a?(Hash) ? log.metadata["changes"] : nil
  end
end
