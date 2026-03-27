# frozen_string_literal: true

module Comments
  class Create < BaseAction
    def call(params:, journal_entry:, user:)
      comment = yield persist(params, journal_entry, user)
      yield subscribe_commenter(journal_entry, user)
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

    def subscribe_commenter(journal_entry, user)
      journal_entry.journal_entry_subscriptions.find_or_create_by!(
        user: user
      )
      Success()
    end

    def emit_event(comment)
      Rails.event.notify(
        "comment.created",
        comment_id: comment.id,
        journal_entry_id: comment.journal_entry_id,
        actor_id: comment.user_id
      )
      Success()
    end
  end
end
