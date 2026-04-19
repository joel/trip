# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webauthn::AaguidLookup do
  describe ".lookup" do
    it "returns the friendly name for a known AAGUID" do
      expect(described_class.lookup("adce0002-35bc-c60a-648b-0b25f1f05503"))
        .to eq("Chrome on Mac")
    end

    it "is case-insensitive" do
      expect(described_class.lookup("ADCE0002-35BC-C60A-648B-0B25F1F05503"))
        .to eq("Chrome on Mac")
    end

    it "returns nil for unknown AAGUIDs" do
      expect(described_class.lookup("00000000-0000-0000-0000-000000000000"))
        .to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.lookup(nil)).to be_nil
      expect(described_class.lookup("")).to be_nil
    end
  end
end
