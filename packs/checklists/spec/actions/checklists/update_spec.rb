# frozen_string_literal: true

require "rails_helper"

RSpec.describe Checklists::Update do
  let(:checklist) { create(:checklist, name: "Old List") }

  it "emits checklist.updated with a changes diff" do
    allow(Rails.event).to receive(:notify)

    described_class.new.call(
      checklist: checklist, params: { name: "New List" }
    )

    expect(Rails.event).to have_received(:notify).with(
      "checklist.updated",
      checklist_id: checklist.id,
      trip_id: checklist.trip_id,
      changes: hash_including("name" => ["Old List", "New List"])
    )
  end

  it "returns failure with invalid params" do
    result = described_class.new.call(
      checklist: checklist, params: { name: "" }
    )
    expect(result).to be_failure
  end
end
