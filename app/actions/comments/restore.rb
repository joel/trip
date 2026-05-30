# frozen_string_literal: true

module Comments
  class Restore < BaseAction
    def call(comment:)
      yield restore(comment)
      yield emit_event(comment)
      Success(comment)
    end

    private

    def restore(comment)
      comment.undiscard!
      Success()
    rescue Discard::RecordNotUndiscarded => e
      Failure(e.message)
    end

    def emit_event(comment)
      Rails.event.notify(
        "comment.restored",
        comment_id: comment.id, journal_entry_id: comment.journal_entry_id
      )
      Success()
    end
  end
end
