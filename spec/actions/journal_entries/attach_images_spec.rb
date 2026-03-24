# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntries::AttachImages do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) do
    create(:journal_entry, trip: trip, author: admin)
  end

  let(:image_data) do
    Rails.root.join("spec/fixtures/files/test_image.jpg").binread
  end

  let(:valid_urls) do
    %w[
      https://example.com/photo1.jpg
      https://example.com/photo2.jpg
    ]
  end

  def ok_response(content_type: "image/jpeg", body: image_data)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive_messages(content_type: content_type, body: body)
    response
  end

  def redirect_response(location)
    response = Net::HTTPFound.new("1.1", "302", "Found")
    allow(response).to receive(:[]).with("location")
                                   .and_return(location)
    response
  end

  before do
    allow(Resolv).to receive(:getaddress)
      .and_return("93.184.216.34")
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive_messages(
      "use_ssl=": nil, "open_timeout=": nil,
      "read_timeout=": nil, "verify_mode=": nil,
      request: ok_response
    )
    allow(entry.images).to receive(:attach)
      .and_return(true)
  end

  describe "#call" do
    it "attaches images from valid URLs" do
      result = described_class.new.call(
        journal_entry: entry, urls: valid_urls
      )

      expect(result).to be_success
      expect(entry.images).to have_received(:attach).twice
    end

    it "does not attach if a later download fails" do
      call_count = 0
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive_messages(
        "use_ssl=": nil, "open_timeout=": nil,
        "read_timeout=": nil, "verify_mode=": nil
      )
      allow(http).to receive(:request) do
        call_count += 1
        raise Timeout::Error if call_count > 1

        ok_response
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
    end

    context "with image count limits" do
      it "rejects when total would exceed maximum" do
        allow(entry.images).to receive(:count)
          .and_return(19)

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
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil
        )
        allow(http).to receive(:request)
          .and_raise(Timeout::Error)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/slow.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Timeout")
      end

      it "handles HTTP errors" do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil
        )
        resp = Net::HTTPNotFound.new("1.1", "404", "Not Found")
        allow(resp).to receive(:code).and_return("404")
        allow(http).to receive(:request).and_return(resp)

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/missing.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("HTTP 404")
      end

      it "handles connection refused" do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil
        )
        allow(http).to receive(:request)
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
      it "rejects localhost" do
        allow(Resolv).to receive(:getaddress)
          .and_return("127.0.0.1")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://localhost/secret"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Blocked host")
      end

      it "rejects private network" do
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

      it "re-validates redirect targets" do # rubocop:disable RSpec/ExampleLength
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil
        )
        allow(http).to receive(:request)
          .and_return(redirect_response(
                        "https://evil.internal/steal"
                      ))
        allow(Resolv).to receive(:getaddress)
          .with("example.com").and_return("93.184.216.34")
        allow(Resolv).to receive(:getaddress)
          .with("evil.internal").and_return("10.0.0.1")

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/redirect.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("Blocked host")
      end

      it "rejects redirect to non-HTTPS" do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil
        )
        allow(http).to receive(:request)
          .and_return(redirect_response(
                        "http://example.com/plain"
                      ))

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/redirect.jpg"]
        )
        expect(result).to be_failure
        expect(result.failure).to include("non-HTTPS")
      end
    end

    context "with content validation" do
      it "rejects non-image content types" do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil,
          request: ok_response(content_type: "text/html")
        )

        result = described_class.new.call(
          journal_entry: entry,
          urls: ["https://example.com/page.html"]
        )
        expect(result).to be_failure
        expect(result.failure).to include(
          "Invalid content type"
        )
      end

      it "rejects oversized files" do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive_messages(
          "use_ssl=": nil, "open_timeout=": nil,
          "read_timeout=": nil, "verify_mode=": nil,
          request: ok_response(body: "x" * 11.megabytes)
        )

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
