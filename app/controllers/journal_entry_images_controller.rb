# frozen_string_literal: true

# Per-item image soft-delete + restore (Phase 26). Active Storage has no native
# soft-delete, so removal detaches the blob without purging into a
# DetachedAttachment and restore re-attaches it (see JournalEntries::RemoveImage
# / RestoreImage). Authorised through JournalEntryPolicy on the parent entry
# (destroy? for remove, restore? for restore — inferred from the action name).
class JournalEntryImagesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :authorize_entry!

  # :id is the blob signed_id of the image tile.
  def destroy
    result = JournalEntries::RemoveImage.new.call(
      journal_entry: @journal_entry, signed_id: params[:id], actor: current_user
    )
    redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)),
                status: :see_other, **flash_for(result, "Image removed.")
  end

  # :id is the DetachedAttachment id (the retention record).
  def restore
    detached = @journal_entry.detached_attachments.find(params[:id])
    result = JournalEntries::RestoreImage.new.call(detached_attachment: detached)
    redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)),
                **flash_for(result, "Image restored.")
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_journal_entry
    @journal_entry = @trip.journal_entries.find(params[:journal_entry_id])
  end

  def authorize_entry!
    authorize!(@journal_entry, with: JournalEntryPolicy)
  end

  def flash_for(result, success_message)
    return { notice: success_message } if result.success?

    { alert: result.failure }
  end
end
