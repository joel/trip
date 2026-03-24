# frozen_string_literal: true

require "net/http"
require "resolv"
require "ipaddr"

module JournalEntries
  class AttachImages < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/webp image/gif
    ].freeze
    MAX_URLS_PER_CALL = 5
    MAX_IMAGES_PER_ENTRY = 20
    MAX_FILE_SIZE = 10.megabytes
    CONNECT_TIMEOUT = 5
    READ_TIMEOUT = 15
    MAX_REDIRECTS = 3

    BLOCKED_NETWORKS = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("198.18.0.0/15"),
      IPAddr.new("240.0.0.0/4"),
      IPAddr.new("::1/128"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10"),
      IPAddr.new("::ffff:0:0/96")
    ].freeze

    def call(journal_entry:, urls:)
      yield validate_urls(urls)
      yield validate_image_count(journal_entry, urls)
      staged = yield download_all(urls)
      yield attach_all(journal_entry, staged)
      yield emit_event(journal_entry, staged.size)
      Success(journal_entry)
    end

    private

    def validate_urls(urls)
      return Failure("urls must be a non-empty array") if urls.blank? || !urls.is_a?(Array)

      if urls.size > MAX_URLS_PER_CALL
        return Failure(
          "Too many URLs (#{urls.size}). " \
          "Maximum is #{MAX_URLS_PER_CALL} per call"
        )
      end

      urls.each do |url|
        uri = URI.parse(url)
        unless uri.scheme == "https"
          return Failure(
            "Only HTTPS URLs are allowed: #{url}"
          )
        end
      rescue URI::InvalidURIError
        return Failure("Invalid URL: #{url}")
      end

      Success()
    end

    def validate_image_count(journal_entry, urls)
      current = journal_entry.images.count
      if current + urls.size > MAX_IMAGES_PER_ENTRY
        return Failure(
          "Would exceed maximum of " \
          "#{MAX_IMAGES_PER_ENTRY} images " \
          "(current: #{current}, adding: #{urls.size})"
        )
      end

      Success()
    end

    def download_all(urls)
      staged = urls.each_with_index.map do |url, idx|
        body, content_type = safe_download(url)
        {
          io: StringIO.new(body),
          filename: derive_filename(url, idx),
          content_type: content_type
        }
      end
      Success(staged)
    rescue DownloadError => e
      Failure(e.message)
    end

    def attach_all(journal_entry, staged)
      staged.each do |attachment|
        journal_entry.images.attach(attachment)
      end
      Success()
    end

    # Downloads with pinned IP resolution and redirect
    # re-validation. Each hop resolves DNS, checks the IP
    # against the blocklist, and connects to the resolved
    # IP directly — preventing TOCTOU DNS rebinding.
    def safe_download(url, redirects_left = MAX_REDIRECTS)
      uri = URI.parse(url)
      ip = resolve_and_validate!(uri)
      response = fetch_with_pinned_ip(uri, ip)

      case response
      when Net::HTTPRedirection
        handle_redirect(response, url, redirects_left)
      when Net::HTTPSuccess
        validate_response!(response, url)
        [response.body, response.content_type]
      else
        raise DownloadError,
              "Failed to download #{url}: " \
              "HTTP #{response.code}"
      end
    end

    def resolve_and_validate!(uri)
      ip = Resolv.getaddress(uri.host)
      addr = IPAddr.new(ip)
      if BLOCKED_NETWORKS.any? { |net| net.include?(addr) }
        raise DownloadError,
              "Blocked host (internal network): " \
              "#{uri.host}"
      end
      ip
    rescue Resolv::ResolvError
      raise DownloadError,
            "Cannot resolve host: #{uri.host}"
    end

    def fetch_with_pinned_ip(uri, ip)
      http = Net::HTTP.new(ip, uri.port || 443)
      http.use_ssl = true
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Host"] = uri.host
      http.request(request)
    rescue SocketError, Errno::ECONNREFUSED
      raise DownloadError, "Cannot connect to #{uri}"
    rescue Timeout::Error
      raise DownloadError, "Timeout downloading #{uri}"
    rescue OpenSSL::SSL::SSLError => e
      raise DownloadError, "SSL error for #{uri}: #{e.message}"
    end

    def handle_redirect(response, original_url, remaining)
      if remaining <= 0
        raise DownloadError,
              "Too many redirects for #{original_url}"
      end

      location = response["location"]
      redirect_uri = URI.parse(location)
      unless redirect_uri.scheme == "https"
        raise DownloadError,
              "Redirect to non-HTTPS URL: #{location}"
      end

      safe_download(location, remaining - 1)
    end

    def validate_response!(response, url)
      ct = response.content_type
      unless ALLOWED_CONTENT_TYPES.include?(ct)
        raise DownloadError,
              "Invalid content type \"#{ct}\" " \
              "for #{url}. " \
              "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
      end

      size = response.body.bytesize
      return if size <= MAX_FILE_SIZE

      raise DownloadError,
            "File too large (#{size} bytes) for #{url}. " \
            "Maximum is #{MAX_FILE_SIZE} bytes"
    end

    def derive_filename(url, index)
      path = URI.parse(url).path
      basename = File.basename(path)
      return "image_#{index}.jpg" if basename.blank? || basename == "/"

      basename
    rescue URI::InvalidURIError
      "image_#{index}.jpg"
    end

    def emit_event(journal_entry, count)
      Rails.event.notify(
        "journal_entry.images_added",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        count: count
      )
      Success()
    end

    class DownloadError < StandardError; end
  end
end
