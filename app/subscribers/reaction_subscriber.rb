# frozen_string_literal: true

class ReactionSubscriber
  def emit(event)
    case event[:name]
    when "reaction.created"
      Rails.logger.info(
        "Reaction created: #{event[:payload][:reaction_id]}"
      )
    when "reaction.removed"
      Rails.logger.info(
        "Reaction removed: #{event[:payload][:reaction_id]}"
      )
    end
  end
end
