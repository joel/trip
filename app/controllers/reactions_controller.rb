# frozen_string_literal: true

class ReactionsController < ApplicationController
  include TurboStreamable

  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :authorize_reaction!, only: [:create]
  before_action :set_and_authorize_reaction!, only: [:destroy]

  def create
    Reactions::Toggle.new.call(
      reactable: @journal_entry,
      user: current_user,
      emoji: params[:emoji]
    )
    @journal_entry.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: stream_replace(
          "reaction_summary_#{@journal_entry.id}",
          reaction_summary_component
        )
      end
      format.html { redirect_to [@trip, @journal_entry] }
    end
  end

  def destroy
    @reaction.destroy!
    @journal_entry.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: stream_replace(
          "reaction_summary_#{@journal_entry.id}",
          reaction_summary_component
        )
      end
      format.html do
        redirect_to [@trip, @journal_entry], status: :see_other
      end
    end
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

  def set_and_authorize_reaction!
    @reaction = @journal_entry.reactions.find(params[:id])
    authorize!(@reaction)
  end

  def reaction_summary_component
    Components::ReactionSummary.new(
      trip: @trip, journal_entry: @journal_entry
    )
  end
end
