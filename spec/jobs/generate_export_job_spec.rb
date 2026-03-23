# frozen_string_literal: true

require "rails_helper"

RSpec.describe GenerateExportJob do
  let(:admin) { create(:user, :superadmin, name: "Admin") }
  let(:trip) do
    create(:trip, :with_dates, name: "Test Trip")
  end
  let(:export) { create(:export, trip: trip, user: admin) }
  let(:tempfile) do
    f = Tempfile.new(["test", ".zip"])
    f.write("fake content")
    f.rewind
    f
  end
  let(:generator) do
    instance_double(Exports::MarkdownGenerator, call: tempfile)
  end

  before do
    create(:journal_entry, trip: trip, author: admin,
                           name: "Day One",
                           entry_date: Date.current)
    allow(Exports::MarkdownGenerator).to receive(:new)
      .and_return(generator)
  end

  after { tempfile.close! if tempfile && !tempfile.closed? }

  it "transitions through processing to completed" do
    described_class.perform_now(export.id)

    export.reload
    expect(export).to be_completed
  end

  it "attaches the generated file" do
    described_class.perform_now(export.id)

    export.reload
    expect(export.file).to be_attached
  end

  it "marks export as failed on generator error" do
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

  it "stays completed when mailer raises" do
    allow(ExportMailer).to receive(:export_ready)
      .and_raise(StandardError, "SMTP down")

    described_class.perform_now(export.id)

    export.reload
    expect(export).to be_completed
  end
end
