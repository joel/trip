# frozen_string_literal: true

module Comments
  class Delete < BaseAction
    def call(comment:)
      comment_id = comment.id
      journal_entry_id = comment.journal_entry_id
      yield destroy(comment)
      yield emit_event(comment_id, journal_entry_id)
      Success()
    end

    private

    def destroy(comment)
      comment.destroy!
      Success()
    end

    def emit_event(comment_id, journal_entry_id)
      Rails.event.notify(
        "comment.deleted",
        comment_id: comment_id,
        journal_entry_id: journal_entry_id
      )
      Success()
    end
  end
end
