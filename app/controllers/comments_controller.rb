# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry
  before_action :set_comment, only: %i[update destroy]
  before_action :authorize_comment!

  def create
    result = Comments::Create.new.call(
      params: comment_params, journal_entry: @journal_entry,
      user: current_user
    )
    case result
    in Dry::Monads::Success(_comment)
      redirect_to [@trip, @journal_entry],
                  notice: "Comment added."
    in Dry::Monads::Failure(errors)
      redirect_to [@trip, @journal_entry],
                  alert: errors.full_messages.join(", ")
    end
  end

  def update
    result = Comments::Update.new.call(
      comment: @comment, params: comment_params
    )
    case result
    in Dry::Monads::Success(_comment)
      redirect_to [@trip, @journal_entry],
                  notice: "Comment updated."
    in Dry::Monads::Failure(errors)
      redirect_to [@trip, @journal_entry],
                  alert: errors.full_messages.join(", ")
    end
  end

  def destroy
    Comments::Delete.new.call(comment: @comment)
    redirect_to [@trip, @journal_entry],
                notice: "Comment deleted.", status: :see_other
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

  def set_comment
    @comment = @journal_entry.comments.find(params[:id])
  end

  def authorize_comment!
    authorize!(
      @comment || @journal_entry.comments.new(user: current_user)
    )
  end

  def comment_params
    params.expect(comment: [:body])
  end
end
