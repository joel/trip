# frozen_string_literal: true

# Per-item video soft-delete + restore (Phase 26). Removes/restores one video
# from a journal entry; the removal surfaces in the Activity feed with a
# Restore button. Authorised by JournalEntryVideoPolicy (entry author or
# superadmin, trip writable).
class JournalEntryVideosController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :set_video, only: %i[destroy]
  before_action :set_discarded_video, only: %i[restore]
  before_action :authorize_video!

  def destroy
    JournalEntryVideos::Delete.new.call(video: @video)
    redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)),
                notice: "Video removed.", status: :see_other
  end

  def restore
    JournalEntryVideos::Restore.new.call(video: @video)
    redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)),
                notice: "Video restored."
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_journal_entry
    @journal_entry = @trip.journal_entries.find(params[:journal_entry_id])
  end

  def set_video
    @video = @journal_entry.videos.find(params[:id])
  end

  # Restore targets a discarded video, hidden by the default kept scope.
  def set_discarded_video
    @video = @journal_entry.videos.with_discarded.find(params[:id])
  end

  def authorize_video!
    authorize!(@video, with: JournalEntryVideoPolicy)
  end
end
