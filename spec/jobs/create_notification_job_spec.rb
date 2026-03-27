# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreateNotificationJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }
  let(:recipient) { create(:user) }

  it "creates a notification record" do
    expect do
      described_class.perform_now(
        notifiable_type: "JournalEntry",
        notifiable_id: entry.id,
        recipient_id: recipient.id,
        actor_id: admin.id,
        event_type: "entry_created"
      )
    end.to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.notifiable).to eq(entry)
    expect(notification.recipient).to eq(recipient)
    expect(notification.actor).to eq(admin)
    expect(notification).to be_entry_created
  end

  it "handles duplicate notifications gracefully" do
    create(:notification,
           notifiable: entry,
           recipient: recipient,
           actor: admin,
           event_type: :entry_created)

    expect do
      described_class.perform_now(
        notifiable_type: "JournalEntry",
        notifiable_id: entry.id,
        recipient_id: recipient.id,
        actor_id: admin.id,
        event_type: "entry_created"
      )
    end.not_to change(Notification, :count)
  end
end
