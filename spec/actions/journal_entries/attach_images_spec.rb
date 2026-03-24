# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::AttachImages do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  let(:fixture_path) do
    Rails.root.join("spec/fixtures/files/test_image.jpg")
  end

  let(:valid_urls) do
    %w[
      https://example.com/photo1.jpg
      https://example.com/photo2.jpg
    ]
  end

  def stub_download(content_type: "image/jpeg", size: 1024)
    allow(URI).to receive(:open) do
      io = StringIO.new(File.binread(fixture_path))
      io.define_singleton_method(:content_type) { content_type }
      io.define_singleton_method(:size) { size }
      io
    end
  end

  before do
    stub_download
    allow(Resolv).to receive(:getaddress)
      .and_return("93.184.216.34")
  end

  describe "#call" do
    before do
      allow(entry.images).to receive(:attach).and_return(true)
    end

    it "attaches images from valid URLs" do
      result = described_class.new.call(
        journal_entry: entry, urls: valid_urls
      )

      expect(result).to be_success
      expect(entry.images).to have_received(:attach).twice
    end

    it "does not attach if a later download fails" do
      call_count = 0
      allow(URI).to receive(:open) do
        call_count += 1
        raise Timeout::Error if call_count > 1

        io = StringIO.new(File.binread(fixture_path))
        io.define_singleton_method(:content_type) { "image/jpeg" }
        io.define_singleton_method(:size) { 1024 }
        io
      end

      result = described_class.new.call(
        journal_entry: entry, urls: valid_urls
      )

      expect(result).to be_failure
      expect(entry.images).not_to have_received(:attach)
    end

    it "emits journal_entry.images_added event" do
      allow(Rails.event).to receive(:notify)

      described_class.new.call(
        journal_entry: entry, urls: valid_urls
      )

      expect(Rails.event).to have_received(:notify).with(
        "journal_entry.images_added",
        journal_entry_id: entry.id,
        trip_id: entry.trip_id,
        count: 2
      )
    end

    context "with invalid URLs" do
      it "rejects empty array" do
        result = described_class.new.call(
          journal_entry: entry, urls: []
        )
        expect(result).to be_failure
        expect(result.failure).to include("non-empty")
      end

      it "rejects non-HTTPS URLs" do
        result = described_class.new.call(
          journal_entry: entry,
          urls: ["http://example.com/photo.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("HTTPS")
      end

      it "rejects too many URLs" do
        urls = (1..6).map do |i|
          "https://example.com/photo#{i}.jpg"
        end
        result = described_class.new.call(
          journal_entry: entry, urls: urls
        )
        expect(result).to be_failure
        expect(result.failure).to include("Too many")
      end

      it "rejects malformed URLs" do
        result = described_class.new.call(
          journal_entry: entry, urls: ["not a url %%%"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Invalid URL")
      end
    end

    context "with image count limits" do
      it "rejects when total would exceed maximum" do
        allow(entry.images).to receive(:count).and_return(19)

        result = described_class.new.call(
          journal_entry: entry,
          urls: %w[
            https://example.com/a.jpg
            https://example.com/b.jpg
          ]
        )
        expect(result).to be_failure
        expect(result.failure).to include("exceed maximum")
      end
    end

    context "with download errors" do
      it "handles timeout" do
        allow(URI).to receive(:open)
          .and_raise(Timeout::Error)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/slow.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Timeout")
      end

      it "handles HTTP errors" do
        allow(URI).to receive(:open)
          .and_raise(OpenURI::HTTPError.new("404", StringIO.new))

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/missing.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Failed to download")
      end

      it "handles connection refused" do
        allow(URI).to receive(:open)
          .and_raise(Errno::ECONNREFUSED)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/down.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Cannot connect")
      end
    end

    context "with SSRF protection" do
      it "rejects localhost URLs" do
        allow(Resolv).to receive(:getaddress)
          .and_return("127.0.0.1")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://localhost/secret"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Blocked host")
      end

      it "rejects private network URLs" do
        allow(Resolv).to receive(:getaddress)
          .and_return("192.168.1.1")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://internal.corp/img.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Blocked host")
      end

      it "rejects cloud metadata endpoint" do
        allow(Resolv).to receive(:getaddress)
          .and_return("169.254.169.254")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://metadata.internal/latest"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Blocked host")
      end

      it "rejects unresolvable hosts" do
        allow(Resolv).to receive(:getaddress)
          .and_raise(Resolv::ResolvError)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://doesnotexist.invalid/x"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Cannot resolve")
      end
    end

    context "with content validation" do
      it "rejects non-image content types" do
        stub_download(content_type: "text/html")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/page.html"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Invalid content type")
      end

      it "rejects oversized files" do
        stub_download(size: 11.megabytes)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/huge.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("File too large")
      end
    end
  end
end
