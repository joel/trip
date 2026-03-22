# frozen_string_literal: true

module Comments
  class Create < BaseAction
    def call(params:, journal_entry:, user:)
      comment = yield persist(params, journal_entry, user)
      yield emit_event(comment)
      Success(comment)
    end

    private

    def persist(params, journal_entry, user)
      comment = journal_entry.comments.create!(
        params.merge(user: user)
      )
      Success(comment)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(comment)
      Rails.event.notify(
        "comment.created",
        comment_id: comment.id,
        journal_entry_id: comment.journal_entry_id
      )
      Success()
    end
  end
end
