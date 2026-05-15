# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLogSubscriber do
  let(:trip) { create(:trip) }

  it "enqueues RecordAuditLogJob with the built attributes" do
    Current.actor = trip.created_by
    event = { name: "trip.created", payload: { trip_id: trip.id } }

    expect { described_class.new.emit(event) }
      .to have_enqueued_job(RecordAuditLogJob)
      .with(hash_including(action: "trip.created", trip_id: trip.id))
  end

  it "skips events the builder does not recognise" do
    event = { name: "widget.frobnicated", payload: {} }
    expect { described_class.new.emit(event) }
      .not_to have_enqueued_job(RecordAuditLogJob)
  end

  it "never raises into the caller and logs on failure" do
    allow(AuditLog::Builder).to receive(:new).and_raise(StandardError, "boom")
    allow(Rails.logger).to receive(:error)

    expect do
      described_class.new.emit(name: "trip.created", payload: {})
    end.not_to raise_error

    expect(Rails.logger).to have_received(:error)
      .with(/\[audit\] trip\.created dropped: StandardError: boom/)
  end

  it "is registered for domain prefixes in the event registry" do
    registry = Rails.root.join("config/initializers/event_subscribers.rb")
                    .read
    expect(registry).to include("AuditLogSubscriber.new")
  end
end
