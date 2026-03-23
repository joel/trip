# frozen_string_literal: true

require "rails_helper"

RSpec.describe Export do
  describe "validations" do
    it "requires format" do
      export = described_class.new(format: nil)
      expect(export).not_to be_valid
      expect(export.errors[:format]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to trip" do
      export = create(:export)
      expect(export.trip).to be_a(Trip)
    end

    it "belongs to user" do
      export = create(:export)
      expect(export.user).to be_a(User)
    end
  end

  describe "enums" do
    it "has format enum" do
      expect(described_class.formats).to eq(
        "markdown" => 0, "epub" => 1
      )
    end

    it "has status enum" do
      expect(described_class.statuses).to eq(
        "pending" => 0, "processing" => 1,
        "completed" => 2, "failed" => 3
      )
    end

    it "defaults to pending status" do
      export = create(:export)
      expect(export).to be_pending
    end
  end

  describe "scopes" do
    it "orders by created_at desc with recent" do
      old = create(:export, created_at: 2.days.ago)
      recent = create(:export, created_at: 1.hour.ago)
      expect(described_class.recent).to eq([recent, old])
    end
  end
end
