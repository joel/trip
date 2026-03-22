# frozen_string_literal: true

# Event subscriber registry for Rails.event structured events.

Rails.application.config.after_initialize do
  Rails.event.subscribe(AccessRequestSubscriber.new) { |e| e[:name].start_with?("access_request.") }
  Rails.event.subscribe(InvitationSubscriber.new) { |e| e[:name] == "invitation.sent" }
  Rails.event.subscribe(OnboardingSubscriber.new) { |e| e[:name] == "invitation.accepted" }
end
