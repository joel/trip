# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyCommentAddedJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }
  let(:subscriber) { create(:user) }
  let(:commenter) { create(:user) }

  before do
    create(:journal_entry_subscription,
           user: subscriber, journal_entry: entry)
    create(:journal_entry_subscription,
           user: commenter, journal_entry: entry)
  end

  it "enqueues CreateNotificationJob for subscribers except commenter" do
    comment = create(:comment, journal_entry: entry, user: commenter)

    expect do
      described_class.perform_now(comment.id, commenter.id)
    end.to have_enqueued_job(CreateNotificationJob).once
  end

  it "enqueues notification email for subscribers except commenter" do
    comment = create(:comment, journal_entry: entry, user: commenter)

    expect do
      described_class.perform_now(comment.id, commenter.id)
    end.to have_enqueued_mail(NotificationMailer, :comment_added)
      .with(comment.id, subscriber.id).once
  end

  it "does nothing if comment not found" do
    expect do
      described_class.perform_now("nonexistent", commenter.id)
    end.not_to have_enqueued_job(CreateNotificationJob)
  end
end
