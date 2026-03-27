# frozen_string_literal: true

class JournalEntrySubscriptionsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :authorize_entry!

  def create
    @journal_entry.journal_entry_subscriptions.find_or_create_by!(
      user: current_user
    )
    redirect_to [@trip, @journal_entry],
                notice: "You are now following this entry."
  end

  def destroy
    @journal_entry.journal_entry_subscriptions
                  .find_by(user: current_user)&.destroy!
    redirect_to [@trip, @journal_entry],
                notice: "You unfollowed this entry.",
                status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_journal_entry
    @journal_entry = @trip.journal_entries.find(
      params[:journal_entry_id]
    )
  end

  def authorize_entry!
    authorize!(@journal_entry, with: JournalEntryPolicy)
  end
end
