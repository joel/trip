# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessJournalImagesJob do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip) }

  it "does not raise for entry without images" do
    entry = create(:journal_entry, trip: trip, author: admin)
    expect do
      described_class.perform_now(entry.id)
    end.not_to raise_error
  end

  it "does not raise for missing entry" do
    expect do
      described_class.perform_now("nonexistent-id")
    end.not_to raise_error
  end
end
