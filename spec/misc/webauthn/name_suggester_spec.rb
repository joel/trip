# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webauthn::NameSuggester do
  describe ".from_user_agent" do
    it "returns 'Passkey' for a blank or nil user agent" do
      expect(described_class.from_user_agent(nil)).to eq("Passkey")
      expect(described_class.from_user_agent("")).to eq("Passkey")
    end

    it "detects iPhone" do
      ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
      expect(described_class.from_user_agent(ua)).to eq("iPhone")
    end

    it "detects iPad" do
      ua = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
      expect(described_class.from_user_agent(ua)).to eq("iPad")
    end

    it "detects Mac with Chrome" do
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0"
      expect(described_class.from_user_agent(ua)).to eq("Mac (Chrome)")
    end

    it "detects Mac with Safari (no Chrome token)" do
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
      expect(described_class.from_user_agent(ua)).to eq("Mac (Safari)")
    end

    it "detects Mac with Edge" do
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0 Edg/120.0"
      expect(described_class.from_user_agent(ua)).to eq("Mac (Edge)")
    end

    it "detects Pixel phone" do
      ua = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36"
      expect(described_class.from_user_agent(ua)).to eq("Pixel phone")
    end

    it "detects generic Android" do
      ua = "Mozilla/5.0 (Linux; Android 14; SM-G998B) AppleWebKit/537.36"
      expect(described_class.from_user_agent(ua)).to eq("Android phone")
    end

    it "detects Windows PC" do
      ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
      expect(described_class.from_user_agent(ua)).to eq("Windows PC")
    end

    it "truncates results longer than 60 chars" do
      stub_const("#{described_class}::DEFAULT", "x" * 100)
      expect(described_class.from_user_agent("").length).to eq(60)
    end
  end
end
