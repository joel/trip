# frozen_string_literal: true

require "tempfile"

module JournalEntries
  # Attach videos from base64-encoded data (parity with UploadImages).
  # Base64 of a large video is impractical over MCP, so this path has
  # a deliberately small ceiling — URL attach (AttachVideos) is the
  # primary path for anything but a short clip. Content type is taken
  # from the bytes (Marcel); ffprobe gates duration on upload.
  class UploadVideos < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      video/mp4 video/quicktime video/webm
    ].freeze
    MAX_VIDEOS_PER_CALL = 2
    MAX_VIDEOS_PER_ENTRY = 5
    MAX_FILE_SIZE = 50.megabytes
    MAX_ENCODED_SIZE = (MAX_FILE_SIZE * 4 / 3) + 4
    MAX_DURATION = 180 # seconds

    MIME_TO_EXT = {
      "video/mp4" => "mp4",
      "video/quicktime" => "mov",
      "video/webm" => "webm"
    }.freeze

    def call(journal_entry:, videos:)
      videos = normalize(videos)
      yield validate_videos(videos)
      yield validate_video_count(journal_entry, videos)
      staged = yield decode_all(videos)
      yield attach_all(journal_entry, staged)
      yield emit_event(journal_entry, staged.size)
      Success(journal_entry)
    ensure
      Array(staged).each { |s| s[:tempfile]&.close! }
    end

    private

    def normalize(videos)
      return videos unless videos.is_a?(Array)

      videos.map do |v|
        v.is_a?(Hash) ? v.transform_keys(&:to_sym) : v
      end
    end

    def validate_videos(videos)
      return Failure("videos must be a non-empty array") if videos.blank? || !videos.is_a?(Array)

      if videos.size > MAX_VIDEOS_PER_CALL
        return Failure(
          "Too many videos (#{videos.size}). " \
          "Maximum is #{MAX_VIDEOS_PER_CALL} per call"
        )
      end

      Success()
    end

    def validate_video_count(journal_entry, videos)
      current = journal_entry.videos.count
      if current + videos.size > MAX_VIDEOS_PER_ENTRY
        return Failure(
          "Would exceed maximum of #{MAX_VIDEOS_PER_ENTRY} " \
          "videos (current: #{current}, adding: #{videos.size})"
        )
      end

      Success()
    end

    def decode_all(videos)
      staged = videos.each_with_index.map { |v, i| decode_one(v, i) }
      Success(staged)
    rescue DecodeError => e
      Failure(e.message)
    end

    def decode_one(video, index)
      data = video[:data]
      raise DecodeError, "Missing data for video #{index}" if data.blank?

      if data.bytesize > MAX_ENCODED_SIZE
        raise DecodeError,
              "Video #{index} data too large " \
              "(encoded size exceeds limit)"
      end

      bytes = Base64.strict_decode64(data)
      content_type = validate_decoded!(bytes, index)
      tempfile = write_tempfile(bytes, index)
      probe = ProbeVideo.call(tempfile.path)
      validate_probe!(probe, index, tempfile)

      {
        tempfile: tempfile,
        filename: video[:filename].presence ||
          "video_#{index}.#{MIME_TO_EXT[content_type]}",
        content_type: content_type,
        duration: probe[:duration],
        width: probe[:width],
        height: probe[:height]
      }
    rescue ArgumentError => e
      raise DecodeError,
            "Invalid base64 data for video #{index}: #{e.message}"
    end

    def validate_decoded!(bytes, index)
      content_type = Marcel::MimeType.for(StringIO.new(bytes))
      unless ALLOWED_CONTENT_TYPES.include?(content_type)
        raise DecodeError,
              "Invalid content type \"#{content_type}\" for " \
              "video #{index}. " \
              "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
      end

      if bytes.bytesize > MAX_FILE_SIZE
        raise DecodeError,
              "Video #{index} too large (#{bytes.bytesize} " \
              "bytes). Maximum is #{MAX_FILE_SIZE} bytes"
      end

      content_type
    end

    def write_tempfile(bytes, index)
      tempfile = Tempfile.new(["upload_video_#{index}", ".bin"])
      tempfile.binmode
      tempfile.write(bytes)
      tempfile.flush
      tempfile
    end

    def validate_probe!(probe, index, tempfile)
      if probe.nil?
        tempfile.close!
        raise DecodeError,
              "Could not read video metadata for video #{index} " \
              "(not a valid video?)"
      end
      return unless probe[:duration] > MAX_DURATION

      tempfile.close!
      raise DecodeError,
            "Video #{index} too long " \
            "(#{probe[:duration].round}s). " \
            "Maximum is #{MAX_DURATION}s"
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

    def emit_event(journal_entry, count)
      Rails.event.notify(
        "journal_entry.videos_added",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        count: count
      )
      Success()
    end

    class DecodeError < StandardError; end
  end
end
