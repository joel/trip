# frozen_string_literal: true

# Event subscriber registry for Rails.event structured events.
# Subscribers will be registered here as domain features are implemented.
#
# Example:
#   Rails.event.subscribe("trip.created", TripSubscriber)
