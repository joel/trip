# frozen_string_literal: true

class TripSubscriber
  def emit(event)
    case event[:name]
    when "trip.created"
      Rails.logger.info(
        "Trip created: #{event[:payload][:trip_id]}"
      )
    when "trip.state_changed"
      Rails.logger.info(
        "Trip #{event[:payload][:trip_id]} " \
        "transitioned from #{event[:payload][:from_state]} " \
        "to #{event[:payload][:to_state]}"
      )
      NotifyTripStateChangeJob.perform_later(
        event[:payload][:trip_id],
        event[:payload][:from_state],
        event[:payload][:to_state]
      )
    end
  end
end
