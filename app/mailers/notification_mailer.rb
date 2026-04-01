# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def entry_created(journal_entry_id, recipient_id)
    @entry = JournalEntry.find_by(id: journal_entry_id)
    @recipient = User.find_by(id: recipient_id)
    return unless @entry && @recipient

    @trip = @entry.trip
    @author = @entry.author
    @entry_url = trip_journal_entry_url(@trip, @entry)
    @email_body_html = sanitize_body_for_email(@entry.body).html_safe # rubocop:disable Rails/OutputSafety
    attach_inline_images

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
    @entry_url = trip_journal_entry_url(@trip, @entry)

    mail(
      to: @recipient.email,
      subject: "New comment on #{@entry.name} in #{@trip.name}"
    )
  end

  private

  def attach_inline_images
    return unless @entry.images.attached?

    @entry.images.each_with_index do |image, index|
      key = "#{index}_#{image.filename}"
      attachments.inline[key] = image.blob.download
    end
  end

  def sanitize_body_for_email(rich_text)
    return "" if rich_text.blank?

    html = rich_text.to_s
    doc = Nokogiri::HTML.fragment(html)
    doc.css("action-text-attachment").each(&:remove)
    doc.to_html
  end
end
