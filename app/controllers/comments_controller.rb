# frozen_string_literal: true

class CommentsController < ApplicationController
  include TurboStreamable

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
    in Dry::Monads::Success(comment)
      respond_to do |format|
        format.turbo_stream { render_created_comment(comment) }
        format.html do
          redirect_to [@trip, @journal_entry],
                      notice: "Comment added."
        end
      end
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
    in Dry::Monads::Success(comment)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: stream_replace(
            dom_id(comment),
            comment_card_component(comment)
          )
        end
        format.html do
          redirect_to [@trip, @journal_entry],
                      notice: "Comment updated."
        end
      end
    in Dry::Monads::Failure(errors)
      redirect_to [@trip, @journal_entry],
                  alert: errors.full_messages.join(", ")
    end
  end

  def destroy
    comment_id = dom_id(@comment)
    Comments::Delete.new.call(comment: @comment)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: stream_remove(comment_id)
      end
      format.html do
        redirect_to [@trip, @journal_entry],
                    notice: "Comment deleted.", status: :see_other
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

  def render_created_comment(comment)
    render turbo_stream: [
      stream_append(
        "comments_#{@journal_entry.id}",
        comment_card_component(comment)
      ),
      stream_replace(
        "comment_form_#{@journal_entry.id}",
        comment_form_component
      )
    ]
  end

  def comment_card_component(comment)
    Components::CommentCard.new(
      trip: @trip, journal_entry: @journal_entry,
      comment: comment
    )
  end

  def comment_form_component
    Components::CommentForm.new(
      trip: @trip, journal_entry: @journal_entry,
      comment: Comment.new
    )
  end
end
