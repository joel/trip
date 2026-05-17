# frozen_string_literal: true

require "json"
require "open3"

module JournalEntries
  # Wraps ffprobe: returns { duration:, width:, height: } for a local
  # file, or nil if the file is not a probeable video. Shared by the
  # ingestion actions (validate-on-upload) and the transcode job.
  module ProbeVideo
    module_function

    def call(path)
      out, status = Open3.capture2e(
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration:stream=width,height,codec_type",
        "-of", "json", path.to_s
      )
      return nil unless status.success?

      parse(out)
    rescue Errno::ENOENT
      nil # ffprobe binary missing — caller treats as unprobeable
    end

    def parse(json)
      data = JSON.parse(json)
      duration = data.dig("format", "duration").to_f
      stream = video_stream(data)
      return nil if duration <= 0 || stream.nil?

      { duration: duration,
        width: stream["width"], height: stream["height"] }
    rescue JSON::ParserError
      nil
    end

    def video_stream(data)
      Array(data["streams"]).find { |s| s["codec_type"] == "video" }
    end
  end
end
