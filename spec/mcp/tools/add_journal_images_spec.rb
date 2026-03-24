# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tools::AddJournalImages do
  let(:entry) { create(:journal_entry) }
  let(:image_data) do
    Rails.root.join("spec/fixtures/files/test_image.jpg").binread
  end

  def ok_response
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive_messages(content_type: "image/jpeg", body: image_data)
    response
  end

  def stub_net_http(response: ok_response)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive_messages(
      "use_ssl=": nil, "open_timeout=": nil,
      "read_timeout=": nil, "verify_mode=": nil,
      request: response
    )
    http
  end

  describe ".call" do
    before do
      allow(Resolv).to receive(:getaddress)
        .and_return("93.184.216.34")
      stub_net_http
      allow_any_instance_of( # rubocop:disable RSpec/AnyInstance
        ActiveStorage::Attached::Many
      ).to receive(:attach).and_return(true)
    end

    it "attaches images and returns count" do
      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be false
      data = JSON.parse(result.content.first[:text])
      expect(data["attached"]).to eq(1)
      expect(data["journal_entry_id"]).to eq(entry.id)
    end

    it "rejects images on non-writable trips" do
      entry.trip.update!(state: :archived)

      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not writable")
    end

    it "returns error for nonexistent journal entry" do
      result = described_class.call(
        journal_entry_id: "nonexistent",
        urls: ["https://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("not found")
    end

    it "rejects non-HTTPS URLs" do
      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["http://example.com/photo.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("HTTPS")
    end

    it "rejects too many URLs" do
      urls = (1..6).map do |i|
        "https://example.com/photo#{i}.jpg"
      end

      result = described_class.call(
        journal_entry_id: entry.id, urls: urls
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Too many")
    end

    it "handles download errors gracefully" do
      http = stub_net_http
      allow(http).to receive(:request)
        .and_raise(Timeout::Error)

      result = described_class.call(
        journal_entry_id: entry.id,
        urls: ["https://example.com/slow.jpg"]
      )

      expect(result.error?).to be true
      expect(result.content.first[:text])
        .to include("Timeout")
    end
  end
end
