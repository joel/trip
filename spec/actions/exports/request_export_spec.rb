# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exports::RequestExport do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip) }

  describe "#call" do
    it "creates an export with valid params" do
      result = described_class.new.call(
        trip: trip, user: admin, format: "markdown"
      )

      expect(result).to be_success
      export = result.value!
      expect(export.trip).to eq(trip)
      expect(export.user).to eq(admin)
      expect(export).to be_markdown
      expect(export).to be_pending
    end

    it "creates an epub export" do
      result = described_class.new.call(
        trip: trip, user: admin, format: "epub"
      )

      expect(result).to be_success
      expect(result.value!).to be_epub
    end

    it "creates the export record in the database" do
      expect do
        described_class.new.call(
          trip: trip, user: admin, format: "markdown"
        )
      end.to change(Export, :count).by(1)
    end

    it "returns failure for invalid format" do
      result = described_class.new.call(
        trip: trip, user: admin, format: "pdf"
      )

      expect(result).to be_failure
    end

    it "prevents duplicate active exports" do
      create(:export, trip: trip, user: admin,
                      format: :markdown, status: :pending)

      result = described_class.new.call(
        trip: trip, user: admin, format: "markdown"
      )

      expect(result).to be_failure
    end

    it "allows new export after previous completes" do
      create(:export, trip: trip, user: admin,
                      format: :markdown, status: :completed)

      result = described_class.new.call(
        trip: trip, user: admin, format: "markdown"
      )

      expect(result).to be_success
    end
  end
end
