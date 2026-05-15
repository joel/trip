# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecordAuditLogJob do
  let(:trip) { create(:trip) }

  def attrs(overrides = {})
    {
      trip_id: trip.id, actor_id: nil, actor_label: "System",
      action: "trip.updated", auditable_type: "Trip",
      auditable_id: trip.id, summary: "System updated trip",
      metadata: {}, source: "web", request_id: "r1",
      event_uid: "r1:trip.updated:#{trip.id}", occurred_at: Time.current
    }.merge(overrides)
  end

  it "creates an audit row" do
    expect { described_class.perform_now(attrs) }
      .to change(AuditLog, :count).by(1)
    expect(AuditLog.last.summary).to eq("System updated trip")
  end

  it "is idempotent on a duplicate event_uid" do
    described_class.perform_now(attrs)
    expect { described_class.perform_now(attrs) }
      .not_to change(AuditLog, :count)
  end

  it "broadcasts the rendered card to the trip stream" do
    allow(ActionCable.server).to receive(:broadcast)
    described_class.perform_now(attrs)
    expect(ActionCable.server).to have_received(:broadcast).with(
      "audit_log:trip_#{trip.id}",
      hash_including(:html, low_signal: false)
    )
  end

  it "marks low-signal rows in the broadcast payload" do
    payload = nil
    allow(ActionCable.server).to receive(:broadcast) do |_stream, data|
      payload = data
    end
    described_class.perform_now(
      attrs(action: "reaction.created", event_uid: "r1:reaction:1")
    )
    expect(payload[:low_signal]).to be(true)
  end

  it "does not broadcast app-wide rows (no trip)" do
    allow(ActionCable.server).to receive(:broadcast)
    described_class.perform_now(
      attrs(trip_id: nil, action: "invitation.sent",
            event_uid: "r1:invitation.sent:1")
    )
    expect(ActionCable.server).not_to have_received(:broadcast)
  end

  it "renders a real card without raising" do
    allow(ActionCable.server).to receive(:broadcast)
    expect { described_class.perform_now(attrs) }.not_to raise_error
  end
end
