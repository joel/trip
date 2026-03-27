# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyEntryCreatedJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:member) { create(:user) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  before do
    create(:trip_membership, trip: trip, user: member)
    create(:trip_membership, trip: trip, user: admin)
  end

  it "enqueues CreateNotificationJob for each trip member except author" do
    expect do
      described_class.perform_now(entry.id, admin.id)
    end.to have_enqueued_job(CreateNotificationJob).once
  end

  it "enqueues notification email for each trip member except author" do
    expect do
      described_class.perform_now(entry.id, admin.id)
    end.to have_enqueued_mail(NotificationMailer, :entry_created)
      .with(entry.id, member.id).once
  end

  it "does nothing if entry not found" do
    expect do
      described_class.perform_now("nonexistent", admin.id)
    end.not_to have_enqueued_job(CreateNotificationJob)
  end
end
