# frozen_string_literal: true

require "rails_helper"

RSpec.describe GenerateExportJob do
  let(:admin) { create(:user, :superadmin, name: "Admin") }
  let(:trip) do
    create(:trip, :with_dates, name: "Test Trip")
  end
  let(:export) { create(:export, trip: trip, user: admin) }

  before do
    create(:journal_entry, trip: trip, author: admin,
                           name: "Day One",
                           entry_date: Date.current)
  end

  it "processes export and attaches file" do
    described_class.perform_now(export.id)

    export.reload
    expect(export).to be_completed
    expect(export.file).to be_attached
  end

  it "marks export as failed on error" do
    generator = instance_double(Exports::MarkdownGenerator)
    allow(Exports::MarkdownGenerator).to receive(:new)
      .and_return(generator)
    allow(generator).to receive(:call)
      .and_raise(StandardError, "boom")

    begin
      described_class.perform_now(export.id)
    rescue StandardError
      nil
    end

    expect(export.reload).to be_failed
  end

  it "sends notification email on completion" do
    expect do
      described_class.perform_now(export.id)
    end.to change {
      ActionMailer::Base.deliveries.count
    }.by(1)
  end
end
