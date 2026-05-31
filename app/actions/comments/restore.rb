# frozen_string_literal: true

module Comments
  # Restores a soft-deleted comment: undiscards it into the kept scope and emits
  # "comment.restored". Resolve the comment via `with_discarded` first (the
  # default kept scope hides it); its parent entry must be kept for the comment
  # to be visible once restored. Returns Failure(message) if it is not discarded.
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
