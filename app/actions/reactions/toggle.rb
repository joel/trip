# frozen_string_literal: true

module Reactions
  class Toggle < BaseAction
    def call(reactable:, user:, emoji:)
      existing = reactable.reactions.find_by(
        user: user, emoji: emoji
      )

      if existing
        remove(existing)
      else
        add(reactable, user, emoji)
      end
    end

    private

    def remove(reaction)
      reaction_id = reaction.id
      reactable_type = reaction.reactable_type
      reactable_id = reaction.reactable_id
      reaction.destroy!
      Rails.event.notify(
        "reaction.removed",
        reaction_id: reaction_id,
        reactable_type: reactable_type,
        reactable_id: reactable_id
      )
      Success(:removed)
    end

    def add(reactable, user, emoji)
      reaction = reactable.reactions.create!(
        user: user, emoji: emoji
      )
      Rails.event.notify(
        "reaction.created",
        reaction_id: reaction.id,
        reactable_type: reaction.reactable_type,
        reactable_id: reaction.reactable_id
      )
      Success(reaction)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end
  end
end
