# frozen_string_literal: true

class CommentSubscriber
  def emit(event)
    case event[:name]
    when "comment.created"
      Rails.logger.info(
        "Comment created: #{event[:payload][:comment_id]}"
      )
    when "comment.updated"
      Rails.logger.info(
        "Comment updated: #{event[:payload][:comment_id]}"
      )
    when "comment.deleted"
      Rails.logger.info(
        "Comment deleted: #{event[:payload][:comment_id]}"
      )
    end
  end
end
