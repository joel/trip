# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def entry_created(journal_entry_id, recipient_id)
    @entry = JournalEntry.find_by(id: journal_entry_id)
    @recipient = User.find_by(id: recipient_id)
    return unless @entry && @recipient

    @trip = @entry.trip
    @author = @entry.author

    mail(
      to: @recipient.email,
      subject: "New entry in #{@trip.name}: #{@entry.name}"
    )
  end

  def comment_added(comment_id, recipient_id)
    @comment = Comment.find_by(id: comment_id)
    @recipient = User.find_by(id: recipient_id)
    return unless @comment && @recipient

    @entry = @comment.journal_entry
    @trip = @entry.trip
    @commenter = @comment.user

    mail(
      to: @recipient.email,
      subject: "New comment on #{@entry.name} in #{@trip.name}"
    )
  end
end
