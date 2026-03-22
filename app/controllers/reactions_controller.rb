# frozen_string_literal: true

class ReactionsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :authorize_reaction!

  def create
    Reactions::Toggle.new.call(
      reactable: @journal_entry,
      user: current_user,
      emoji: params[:emoji]
    )
    redirect_to [@trip, @journal_entry]
  end

  def destroy
    reaction = @journal_entry.reactions.find(params[:id])
    reaction.destroy!
    redirect_to [@trip, @journal_entry], status: :see_other
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

  def authorize_reaction!
    authorize!(
      @journal_entry.reactions.new(user: current_user)
    )
  end
end
