# frozen_string_literal: true

# Event subscriber registry for Rails.event structured events.

Rails.application.config.after_initialize do
  Rails.event.subscribe(AccessRequestSubscriber.new) { |e| e[:name].start_with?("access_request.") }
  Rails.event.subscribe(InvitationSubscriber.new) { |e| e[:name] == "invitation.sent" }
  Rails.event.subscribe(OnboardingSubscriber.new) { |e| e[:name] == "invitation.accepted" }
  Rails.event.subscribe(TripSubscriber.new) { |e| e[:name].start_with?("trip.") }
  Rails.event.subscribe(JournalEntrySubscriber.new) { |e| e[:name].start_with?("journal_entry.") }
  Rails.event.subscribe(TripMembershipSubscriber.new) { |e| e[:name].start_with?("trip_membership.") }
  Rails.event.subscribe(CommentSubscriber.new) { |e| e[:name].start_with?("comment.") }
  Rails.event.subscribe(ReactionSubscriber.new) { |e| e[:name].start_with?("reaction.") }
  Rails.event.subscribe(ChecklistSubscriber.new) { |e| e[:name].start_with?("checklist") }
  Rails.event.subscribe(ExportSubscriber.new) { |e| e[:name].start_with?("export.") }
  Rails.event.subscribe(NotificationSubscriber.new) do |e|
    e[:name].in?(%w[journal_entry.created comment.created])
  end
  Rails.event.subscribe(AuditLogSubscriber.new) do |e|
    e[:name].start_with?(
      "trip.", "trip_membership.", "journal_entry.", "comment.",
      "reaction.", "checklist", "export.", "access_request.",
      "invitation."
    )
  end
end
