# frozen_string_literal: true

require "net/http"
require "resolv"
require "ipaddr"
require "tempfile"

module JournalEntries
  # Attach videos to a journal entry from HTTPS URLs. The SSRF
  # hardening (pinned-IP DNS resolution, blocked private networks,
  # redirect re-validation) is the AttachImages stack, kept faithful;
  # the download streams to a Tempfile with a hard byte cap (videos
  # are large) and a synchronous ffprobe duration gate so format/size/
  # duration are validated *on upload* (fail fast). Each accepted file
  # becomes a JournalEntryVideo(:pending); transcoding is async.
  class AttachVideos < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      video/mp4 video/quicktime video/webm
    ].freeze
    MAX_URLS_PER_CALL = 3
    MAX_VIDEOS_PER_ENTRY = 5
    MAX_FILE_SIZE = 200.megabytes
    MAX_DURATION = 180 # seconds
    CONNECT_TIMEOUT = 5
    READ_TIMEOUT = 60
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
      yield validate_video_count(journal_entry, urls)
      staged = yield download_all(urls)
      yield attach_all(journal_entry, staged)
      yield emit_event(journal_entry, staged.size)
      Success(journal_entry)
    ensure
      Array(staged).each { |s| s[:tempfile]&.close! }
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
      rescue URI::InvalidURIError
        return Failure("Invalid URL: #{url}")
      end

      Success()
    end

    def validate_video_count(journal_entry, urls)
      current = journal_entry.videos.count
      if current + urls.size > MAX_VIDEOS_PER_ENTRY
        return Failure(
          "Would exceed maximum of #{MAX_VIDEOS_PER_ENTRY} " \
          "videos (current: #{current}, adding: #{urls.size})"
        )
      end

      Success()
    end

    def download_all(urls)
      staged = urls.each_with_index.map do |url, idx|
        tempfile, content_type = safe_download(url, idx)
        probe = ProbeVideo.call(tempfile.path)
        validate_probe!(probe, url)
        {
          tempfile: tempfile,
          filename: derive_filename(url, idx),
          content_type: content_type,
          duration: probe[:duration],
          width: probe[:width],
          height: probe[:height]
        }
      end
      Success(staged)
    rescue DownloadError => e
      Failure(e.message)
    end

    def attach_all(journal_entry, staged)
      ActiveRecord::Base.transaction do
        base = journal_entry.videos.maximum(:position).to_i
        staged.each_with_index do |s, i|
          video = journal_entry.videos.create!(
            status: :pending, position: base + i + 1,
            duration: s[:duration], width: s[:width],
            height: s[:height]
          )
          video.source.attach(
            io: File.open(s[:tempfile].path),
            filename: s[:filename],
            content_type: s[:content_type]
          )
        end
      end
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    # Pinned-IP resolution + redirect re-validation (TOCTOU-safe),
    # streaming the body to a Tempfile with a hard byte cap.
    def safe_download(url, idx, redirects_left = MAX_REDIRECTS)
      uri = URI.parse(url)
      ip = resolve_and_validate!(uri)
      fetch_with_pinned_ip(uri, ip, url, idx, redirects_left)
    end

    def resolve_and_validate!(uri)
      ip = Resolv.getaddress(uri.host)
      addr = IPAddr.new(ip)
      if BLOCKED_NETWORKS.any? { |net| net.include?(addr) }
        raise DownloadError,
              "Blocked host (internal network): #{uri.host}"
      end
      ip
    rescue Resolv::ResolvError
      raise DownloadError, "Cannot resolve host: #{uri.host}"
    end

    def fetch_with_pinned_ip(uri, ip, url, idx, redirects_left)
      http = Net::HTTP.new(ip, uri.port || 443)
      http.use_ssl = true
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Host"] = uri.host

      http.request(request) do |response|
        return handle_response(response, url, idx, redirects_left)
      end
    rescue SocketError, Errno::ECONNREFUSED
      raise DownloadError, "Cannot connect to #{uri}"
    rescue Timeout::Error
      raise DownloadError, "Timeout downloading #{uri}"
    rescue OpenSSL::SSL::SSLError => e
      raise DownloadError, "SSL error for #{uri}: #{e.message}"
    end

    def handle_response(response, url, idx, redirects_left)
      case response
      when Net::HTTPRedirection
        handle_redirect(response, url, idx, redirects_left)
      when Net::HTTPSuccess
        validate_content_type!(response, url)
        [stream_to_tempfile(response, url, idx),
         response.content_type]
      else
        raise DownloadError,
              "Failed to download #{url}: HTTP #{response.code}"
      end
    end

    def handle_redirect(response, original_url, idx, remaining)
      raise DownloadError, "Too many redirects for #{original_url}" if remaining <= 0

      location = response["location"]
      redirect_uri = URI.parse(location)
      raise DownloadError, "Redirect to non-HTTPS URL: #{location}" unless redirect_uri.scheme == "https"

      safe_download(location, idx, remaining - 1)
    end

    def validate_content_type!(response, url)
      ct = response.content_type
      return if ALLOWED_CONTENT_TYPES.include?(ct)

      raise DownloadError,
            "Invalid content type \"#{ct}\" for #{url}. " \
            "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
    end

    def stream_to_tempfile(response, url, idx)
      tempfile = Tempfile.new(["video_#{idx}", ".bin"])
      tempfile.binmode
      size = 0
      response.read_body do |chunk|
        size += chunk.bytesize
        if size > MAX_FILE_SIZE
          tempfile.close!
          raise DownloadError,
                "File too large (> #{MAX_FILE_SIZE} bytes) " \
                "for #{url}"
        end
        tempfile.write(chunk)
      end
      tempfile.flush
      tempfile
    end

    def validate_probe!(probe, url)
      if probe.nil?
        raise DownloadError,
              "Could not read video metadata for #{url} " \
              "(not a valid video?)"
      end
      return unless probe[:duration] > MAX_DURATION

      raise DownloadError,
            "Video too long (#{probe[:duration].round}s) for " \
            "#{url}. Maximum is #{MAX_DURATION}s"
    end

    def derive_filename(url, index)
      basename = File.basename(URI.parse(url).path)
      return "video_#{index}.mp4" if basename.blank? || basename == "/"

      basename
    rescue URI::InvalidURIError
      "video_#{index}.mp4"
    end

    def emit_event(journal_entry, count)
      Rails.event.notify(
        "journal_entry.videos_added",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        count: count
      )
      Success()
    end

    class DownloadError < StandardError; end
  end
end
