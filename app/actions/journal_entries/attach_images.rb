# frozen_string_literal: true

require "open-uri"
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
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    BLOCKED_NETWORKS = [
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("::1/128"),
      IPAddr.new("fc00::/7")
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
        return Failure("Only HTTPS URLs are allowed: #{url}") unless uri.scheme == "https"

        validate_host!(uri)
      rescue URI::InvalidURIError
        return Failure("Invalid URL: #{url}")
      rescue DownloadError => e
        return Failure(e.message)
      end

      Success()
    end

    def validate_host!(uri)
      ip = Resolv.getaddress(uri.host)
      addr = IPAddr.new(ip)
      return unless BLOCKED_NETWORKS.any? { |net| net.include?(addr) }

      raise DownloadError,
            "Blocked host (internal network): #{uri.host}"
    rescue Resolv::ResolvError
      raise DownloadError,
            "Cannot resolve host: #{uri.host}"
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
        io = download(url)
        validate_content_type!(io, url)
        validate_file_size!(io, url)
        {
          io: io,
          filename: derive_filename(url, idx),
          content_type: io.content_type
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

    def download(url)
      URI.open( # rubocop:disable Security/Open
        url,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      )
    rescue OpenURI::HTTPError => e
      raise DownloadError,
            "Failed to download #{url}: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED
      raise DownloadError, "Cannot connect to #{url}"
    rescue Timeout::Error
      raise DownloadError, "Timeout downloading #{url}"
    end

    def validate_content_type!(io, url)
      return if ALLOWED_CONTENT_TYPES.include?(io.content_type)

      raise DownloadError,
            "Invalid content type " \
            "\"#{io.content_type}\" for #{url}. " \
            "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
    end

    def validate_file_size!(io, url)
      return if io.size <= MAX_FILE_SIZE

      raise DownloadError,
            "File too large (#{io.size} bytes) " \
            "for #{url}. Maximum is #{MAX_FILE_SIZE} bytes"
    end

    def derive_filename(url, index)
      basename = File.basename(URI.parse(url).path)
      basename.presence || "image_#{index}.jpg"
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
