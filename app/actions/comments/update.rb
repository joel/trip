# frozen_string_literal: true

module Comments
  class Update < BaseAction
    def call(comment:, params:)
      yield persist(comment, params)
      yield emit_event(comment)
      Success(comment)
    end

    private

    def persist(comment, params)
      comment.update!(params)
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(comment)
      Rails.event.notify(
        "comment.updated",
        comment_id: comment.id,
        journal_entry_id: comment.journal_entry_id
      )
      Success()
    end
  end
end
