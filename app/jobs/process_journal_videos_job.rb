# frozen_string_literal: true

require "open3"
require "tmpdir"

# Transcodes each pending JournalEntryVideo to one web-friendly
# rendition (≤720p H.264 + AAC, +faststart) and extracts a poster
# frame, off the request/agent path. Idempotent (only `pending`).
# A bad clip must never break the journal feed: every failure is
# converted to status: :failed + error_message and logged — the job
# never re-raises.
class ProcessJournalVideosJob < ApplicationJob
  queue_as :default

  MAX_DIMENSION = 1280 # longest edge cap (~720p class)

  def perform(journal_entry_id)
    entry = JournalEntry.find_by(id: journal_entry_id)
    return unless entry

    entry.videos.where(status: :pending).find_each do |video|
      process(video)
    end
  end

  private

  def process(video)
    video.processing!
    Dir.mktmpdir do |dir|
      src = download_source(video, dir)
      web = transcode(src, dir)
      poster = extract_poster(src, dir)
      probe = JournalEntries::ProbeVideo.call(web) ||
              JournalEntries::ProbeVideo.call(src)

      attach_outputs(video, web, poster)
      video.update!(
        status: :ready,
        duration: probe&.dig(:duration) || video.duration,
        width: probe&.dig(:width) || video.width,
        height: probe&.dig(:height) || video.height
      )
    end
  rescue StandardError => e
    video.update(status: :failed,
                 error_message: e.message.to_s.truncate(500))
    Rails.logger.error(
      "ProcessJournalVideosJob video=#{video.id} failed: #{e.message}"
    )
  end

  def download_source(video, dir)
    path = File.join(dir, "source")
    File.binwrite(path, video.source.download)
    path
  end

  def transcode(src, dir)
    out = File.join(dir, "web.mp4")
    run!(
      "ffmpeg", "-y", "-i", src,
      # Cap the *longest* edge at MAX (portrait clips too) without
      # ever upscaling; `-2`/`min` keep aspect and even dimensions
      # for yuv420p/libx264.
      "-vf",
      "scale=" \
      "'if(gt(iw,ih),min(#{MAX_DIMENSION},iw),-2)':" \
      "'if(gt(iw,ih),-2,min(#{MAX_DIMENSION},ih))'",
      "-c:v", "libx264", "-profile:v", "main",
      "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
      "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart", out
    )
    out
  end

  def extract_poster(src, dir)
    out = File.join(dir, "poster.jpg")
    status = ffmpeg_ok?(
      "ffmpeg", "-y", "-ss", "00:00:01", "-i", src,
      "-frames:v", "1", "-q:v", "3", out
    )
    # Clips shorter than the seek point: grab the first frame.
    unless status && File.exist?(out) && File.size?(out)
      run!("ffmpeg", "-y", "-i", src, "-frames:v", "1",
           "-q:v", "3", out)
    end
    out
  end

  def attach_outputs(video, web, poster)
    video.web.attach(
      ActiveStorageBlobBuilder.upload(
        io: File.open(web), filename: "web.mp4",
        content_type: "video/mp4"
      )
    )
    video.poster.attach(
      ActiveStorageBlobBuilder.upload(
        io: File.open(poster), filename: "poster.jpg",
        content_type: "image/jpeg"
      )
    )
  end

  def run!(*cmd)
    out, status = Open3.capture2e(*cmd)
    return if status.success?

    raise "ffmpeg failed (#{cmd[0..2].join(" ")}…): " \
          "#{out.lines.last(3).join.strip}"
  end

  def ffmpeg_ok?(*cmd)
    _out, status = Open3.capture2e(*cmd)
    status.success?
  end
end
